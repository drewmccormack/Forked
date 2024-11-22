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
/// This type represesnts the array internally as a tree, which generally leads to more intuitive merging
/// of conflicting versions. You could use this as the basis of a basic collaborative editor.
/// Note that it contains a complete history of changes, including deletions, so it grows over time.
/// If you need a more compact representation, consider using a merger instead.
public struct MergableArray<Element> {
    
    fileprivate struct ValueContainer: Identifiable {
        var anchor: ID?
        var value: Element
        var lamportTimestamp: UInt64
        var id: UUID = UUID()
        var isDeleted: Bool = false
        
        init(anchor: ValueContainer.ID?, value: Element, lamportTimestamp: UInt64) {
            self.anchor = anchor
            self.value = value
            self.lamportTimestamp = lamportTimestamp
        }
        
        func ordered(beforeSibling other: ValueContainer) -> Bool {
            (lamportTimestamp, id.uuidString) > (other.lamportTimestamp, other.id.uuidString)
        }
    }
    
    private var valueContainers: Array<ValueContainer> = []
    private var tombstones: Array<ValueContainer> = []
    
    public var values: Array<Element> {
        valueContainers.map { $0.value }
    }
    
    public var count: UInt64 { UInt64(valueContainers.count) }
    
    private var lamportTimestamp: UInt64 = 0
    private mutating func tick() { lamportTimestamp += 1 }
        
    public init() {}
    
    public init(_ array: [Element]) {
        array.forEach { append($0) }
    }
}

public extension MergableArray {
        
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
        let new = ValueContainer(anchor: anchor, value: value, lamportTimestamp: lamportTimestamp)
        return new
    }
}

public extension MergableArray {
        
    @discardableResult mutating func remove(at index: Int) -> Element {
        var tombstone = valueContainers[index]
        tombstone.isDeleted = true
        tombstones.append(tombstone)
        valueContainers.remove(at: index)
        return tombstone.value
    }
    
}

public extension MergableArray where Element: Equatable {
    
    var values: Array<Element> {
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
    
}

extension MergableArray: ConflictFreeMergable {
    
    /// Merges two versions of the array. No common ancestor is needed, because the complete history is stored in the type.
    public func merged(with other: Self) -> Self {
        let resultTombstones = (tombstones + other.tombstones).filterDuplicates { $0.id }
        let tombstoneIds = resultTombstones.map { $0.id }
        
        var encounteredIds: Set<ValueContainer.ID> = []
        let unorderedValueContainers = (valueContainers + other.valueContainers).filter {
            !tombstoneIds.contains($0.id) && encounteredIds.insert($0.id).inserted
        }
        
        let resultValueContainersWithTombstones = MergableArray.ordered(fromUnordered: unorderedValueContainers + resultTombstones)
        let resultValueContainers = resultValueContainersWithTombstones.filter { !$0.isDeleted }
        
        var result = self
        result.valueContainers = resultValueContainers
        result.tombstones = resultTombstones
        result.lamportTimestamp = Swift.max(self.lamportTimestamp, other.lamportTimestamp)
        return result
    }
    
}

extension MergableArray {
    
    /// Not just sorted, but ordered according to a preorder traversal of the tree.
    /// For each element, we insert the element itself first, then the child (anchored) subtrees from left to right.
    private static func ordered(fromUnordered unordered: [ValueContainer]) -> [ValueContainer] {
        let sorted = unordered.sorted { $0.ordered(beforeSibling: $1) }
        let anchoredByAnchorId: [ValueContainer.ID? : [ValueContainer]] = .init(grouping: sorted) { $0.anchor }
        var result: [ValueContainer] = []
        
        func addDecendants(of containers: [ValueContainer]) {
            for container in containers {
                result.append(container)
                guard let anchoredToValueContainer = anchoredByAnchorId[container.id] else { continue }
                addDecendants(of: anchoredToValueContainer)
            }
        }
        
        let roots = anchoredByAnchorId[nil] ?? []
        addDecendants(of: roots)
        return result
    }
    
}


extension MergableArray: ExpressibleByArrayLiteral {
    
    public init(arrayLiteral elements: Element...) {
        elements.forEach { self.append($0) }
    }
    
}

extension MergableArray: Collection, RandomAccessCollection {

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

private extension Array {
    
    func filterDuplicates(identifyingWith block: (Element)->AnyHashable) -> Self {
        var encountered: Set<AnyHashable> = []
        return filter { encountered.insert(block($0)).inserted }
    }

}

extension MergableArray: Codable where Element: Codable {}
extension MergableArray.ValueContainer: Codable where Element: Codable {}

extension MergableArray: Equatable where Element: Equatable {}
extension MergableArray.ValueContainer: Equatable where Element: Equatable {}

extension MergableArray: Hashable where Element: Hashable {}
extension MergableArray.ValueContainer: Hashable where Element: Hashable {}
