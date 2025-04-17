import Foundation
import Forked

/// Represents a CRDT for an array of values, such as characters in a string.
/// The stress here is on values, because this array does not guarantee that uniqueness of
/// elements is preserverd. After a merge, it is possible that multiple copies of the same element
/// may be present. Think about merging changes to text: If the user types the same word on two
/// devices at the same time, after the merge, you will have the same word twice — the value is
/// inserted twice, and there is no check that the value already exists in the array.
/// This type is typically useful for strings in collaborative environments, and less useful for
/// storing identifiable objects, since you can end up with duplicates. If you use it for this purpose,
/// you should dedupe after every merge.
/// This type represents the array internally as a tree, which generally leads to more intuitive merging
/// of conflicting versions. You could use this as the basis of a basic collaborative editor.
/// Note that it contains a complete history of changes, including deletions, so it grows over time.
/// If you need a more compact representation, consider using a merger instead.
public struct MergeableArray<Element: Equatable>: Equatable {
    
    fileprivate struct ValueContainer: Identifiable, Equatable {
        var anchor: ID?
        var value: Element
        var timestamp: StableTimestamp
        var id: UUID = UUID()
        var isDeleted: Bool = false
        
        init(anchor: ValueContainer.ID?, value: Element, timestamp: StableTimestamp) {
            self.anchor = anchor
            self.value = value
            self.timestamp = timestamp
        }
        
        func ordered(beforeSibling other: ValueContainer) -> Bool {
            timestamp > other.timestamp
        }
    }
    
    private var valueContainers: Array<ValueContainer> = []
    private var tombstones: Array<ValueContainer> = []
    
    public var values: Array<Element> {
        get {
            valueContainers.map { $0.value }
        }
        set {
            for diff in newValue.difference(from: values) {
                switch diff {
                case let .insert(offset, element, _):
                    insert(element, at: offset)
                case let .remove(offset, _, _):
                    remove(at: offset)
                }
            }
        }
    }
    
    public var count: UInt64 { UInt64(valueContainers.count) }
    
    private var timestamp: StableTimestamp = .init()
    private mutating func tick() { timestamp.tick() }
        
    public init() {}
    
    public init(_ array: [Element]) {
        array.forEach { append($0) }
    }
}

public extension MergeableArray {
        
    mutating func insert(_ newValue: Element, at index: Int) {
        tick()
        let new = makeValueContainer(withValue: newValue, forInsertingAtIndex: index)
        valueContainers.insert(new, at: index)
    }
    
    mutating func append(_ newValue: Element) {
        insert(newValue, at: valueContainers.count)
    }
    
    private func makeValueContainer(withValue value: Element, forInsertingAtIndex index: Int) -> ValueContainer {
        let anchor = index > 0 ? valueContainers[index-1].id : nil
        let new = ValueContainer(anchor: anchor, value: value, timestamp: timestamp)
        return new
    }
}

public extension MergeableArray {
        
    @discardableResult mutating func remove(at index: Int) -> Element {
        var tombstone = valueContainers[index]
        tombstone.isDeleted = true
        tombstones.append(tombstone)
        valueContainers.remove(at: index)
        return tombstone.value
    }
    
}

extension MergeableArray: Mergeable {
    
    /// Default merge, when elements are not mergeable. Eg chars in a string
    public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
        try mergedNonrecursively(with: other)
    }
    
    private func mergedNonrecursively(with other: Self) throws -> Self {
        let resultTombstones = (tombstones + other.tombstones).filterDuplicates { $0.id }
        let tombstoneIds = resultTombstones.map { $0.id }
        
        var encounteredIds: Set<ValueContainer.ID> = []
        let unorderedValueContainers = (valueContainers + other.valueContainers).filter {
            !tombstoneIds.contains($0.id) && encounteredIds.insert($0.id).inserted
        }
        
        let resultValueContainersWithTombstones = MergeableArray.ordered(fromUnordered: unorderedValueContainers + resultTombstones)
        let resultValueContainers = resultValueContainersWithTombstones.filter { !$0.isDeleted }
        
        var result = self
        result.valueContainers = resultValueContainers
        result.tombstones = resultTombstones
        result.timestamp = Swift.max(self.timestamp, other.timestamp)
        return result
    }
}

extension MergeableArray where Element: Identifiable & Mergeable {
    
    /// Merge when elements are mergeable and identifiable. More object-like.
    /// Will ensure uniqueness of identifiers, and merge together elements with the same identifier.
    public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
        try mergedRecursively(with: other, commonAncestor: commonAncestor, mergeElementFunc: mergeElement)
    }
    
    private func mergeElement(_ element: Element, _ otherElement: Element, _ commonAncestor: Element) throws -> Element {
        try element.merged(withSubordinate: otherElement, commonAncestor: commonAncestor)
    }
    
}
    
extension MergeableArray where Element: Identifiable {
    
    /// For non-mergeables that are identifiable and equatable. Here we can at least see
    /// which branch has changed, and choose that branch, even if we can't "fuse" the elements.
    public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
        try mergedRecursively(with: other, commonAncestor: commonAncestor, mergeElementFunc: mergeElement)
    }
    
    private func mergeElement(_ element: Element, _ otherElement: Element, _ commonAncestor: Element) throws -> Element {
        element == commonAncestor ? otherElement : element
    }
    
    private func mergedRecursively(with other: Self, commonAncestor: Self, mergeElementFunc: (Element, _ other: Element, _ ancestor: Element) throws -> Element) throws -> Self {
        var result = try mergedNonrecursively(with: other).entriesUniquelyIdentified()
        let idToElement: [Element.ID:Element] = .init(uniqueKeysWithValues: self.values.filterDuplicates(identifyingWith: { $0.id }).map { ($0.id, $0) })
        let idToOtherElement: [Element.ID:Element] = .init(uniqueKeysWithValues: other.values.filterDuplicates(identifyingWith: { $0.id }).map { ($0.id, $0) })
        let idToAncestorElement: [Element.ID:Element] = .init(uniqueKeysWithValues: commonAncestor.values.filterDuplicates(identifyingWith: { $0.id }).map { ($0.id, $0) })
        let resultIds = result.values.map(\.id)
        let resultElements = try resultIds.map { id in
            switch (idToElement[id], idToOtherElement[id], idToAncestorElement[id]) {
            case let (element?, otherElement?, ancestorElement?):
                return try mergeElementFunc(element, otherElement, ancestorElement)
            case let (element?, _, _), let (nil, element?, _):
                return element
            case (nil, nil, _):
                fatalError("Missing element with id \(id)")
            }
        }
        result.values = resultElements
        return result
    }

    /// Returns a new array with entries uniquely identified, keeping only the most recently modified instance of each uniquely identified element.
    /// The relative order of the remaining elements is preserved.
    public func entriesUniquelyIdentified() -> Self {
        var result = self
        var seen = Set<Element.ID>()
        var mostRecentContainerByID: [Element.ID: ValueContainer] = [:]
        
        // First pass: find the most recent container for each ID
        for container in result.valueContainers {
            let id = container.value.id
            if let existing = mostRecentContainerByID[id] {
                if container.timestamp > existing.timestamp {
                    mostRecentContainerByID[id] = container
                }
            } else {
                mostRecentContainerByID[id] = container
            }
        }
        
        // Second pass: keep most recent versions and create tombstones for others
        var newValueContainers: [ValueContainer] = []
        var newTombstones = result.tombstones
        
        for container in result.valueContainers {
            let id = container.value.id
            guard let mostRecent = mostRecentContainerByID[id] else { continue }
            
            // Explicit conversion to optional UUID for comparison
            let containerIdOptional: ValueContainer.ID? = container.id 
            let mostRecentIdOptional: ValueContainer.ID? = mostRecent.id
            
            if containerIdOptional == mostRecentIdOptional && seen.insert(id).inserted {
                newValueContainers.append(container)
            } else {
                var tombstone = container
                tombstone.isDeleted = true
                newTombstones.append(tombstone)
            }
        }
        
        result.valueContainers = newValueContainers
        result.tombstones = newTombstones
        return result
    }
    
}

extension MergeableArray {
    
    /// Not just sorted, but ordered according to a preorder traversal of the tree.
    /// For each element, we insert the element itself first, then the child (anchored) subtrees from left to right.
    private static func ordered(fromUnordered unordered: [ValueContainer]) -> [ValueContainer] {
        let sorted = unordered.sorted { $0.ordered(beforeSibling: $1) }
        let anchoredByAnchorId: [ValueContainer.ID? : [ValueContainer]] = .init(grouping: sorted) { $0.anchor }
        var result: [ValueContainer] = []
        
        // Use an explicit stack instead of recursion to avoid stack overflow
        var stack: [ValueContainer] = anchoredByAnchorId[nil] ?? []
        var visitedIds = Set<ValueContainer.ID>()
        
        // Process nodes in a depth-first order
        while !stack.isEmpty {
            // Take the last container from the stack
            let container = stack.removeLast()
            
            // Add to result if not already visited
            if visitedIds.insert(container.id).inserted {
                result.append(container)
                
                // Find children and add them to the stack in reverse order
                // (so they get processed in the correct order when popped)
                let optionalId: ValueContainer.ID? = container.id
                if let children = anchoredByAnchorId[optionalId] {
                    // Add in reverse order so they get processed in the right order
                    for child in children.reversed() {
                        stack.append(child)
                    }
                }
            }
        }
        
        return result
    }
    
}


extension MergeableArray: ExpressibleByArrayLiteral {
    
    public init(arrayLiteral elements: Element...) {
        elements.forEach { self.append($0) }
    }
    
}

extension MergeableArray: Collection, RandomAccessCollection {

    public var startIndex: Int { return valueContainers.startIndex }
    public var endIndex: Int { return valueContainers.endIndex }
    public func index(after i: Int) -> Int { valueContainers.index(after: i) }
    
    public subscript(_ i: Int) -> Element {
        get {
            valueContainers[i].value
        }
        set {
            remove(at: i)
            tick()
            let newValueContainer = makeValueContainer(withValue: newValue, forInsertingAtIndex: i)
            valueContainers.insert(newValueContainer, at: i)
        }
    }
}

extension Array {
    
    func filterDuplicates(identifyingWith block: (Element)->AnyHashable) -> Self {
        var encountered: Set<AnyHashable> = []
        return filter { encountered.insert(block($0)).inserted }
    }
}

extension MergeableArray: Codable where Element: Codable {}
extension MergeableArray.ValueContainer: Codable where Element: Codable {}

extension MergeableArray: Hashable where Element: Hashable {}
extension MergeableArray.ValueContainer: Hashable where Element: Hashable {}
