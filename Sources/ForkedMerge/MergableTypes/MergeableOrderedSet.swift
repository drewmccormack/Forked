import Foundation
import Forked

/// Ordered Set which can be merged. Maintains uniqueness like a set but preserves insertion order.
/// Elements can be reordered and the order is preserved across merges when possible.
/// Not suitable for collaborative editing, but should work fine for most manually ordered lists.
public struct MergeableOrderedSet<T: Hashable & Comparable> {
    
    fileprivate struct Metadata {
        var isDeleted: Bool
        var timestamp: StableTimestamp
        var orderPriority: Double
        
        init(timestamp: StableTimestamp, orderPriority: Double) {
            self.isDeleted = false
            self.timestamp = timestamp
            self.orderPriority = orderPriority
        }
    }
    
    private var metadataByValue: [T:Metadata]
    private var currentTimestamp: StableTimestamp
    
    public var values: [T] {
        get {
            metadataByValue
                .filter { !$1.isDeleted }
                .sorted { pair1, pair2 in
                    if pair1.value.orderPriority != pair2.value.orderPriority {
                        return pair1.value.orderPriority < pair2.value.orderPriority
                    }
                    return pair1.key < pair2.key
                }
                .map { $0.key }
        }
        set {
            let old = Set(self.values)
            let new = Set(newValue)
            
            // Remove items not in new set
            let deleted = old.subtracting(new)
            deleted.forEach { remove($0) }
            
            // Add/reorder items from new array
            for (index, value) in newValue.enumerated() {
                if old.contains(value) {
                    move(value, toIndex: index)
                } else {
                    insert(value, at: index)
                }
            }
        }
    }
    
    public var count: Int {
        metadataByValue.reduce(0) { result, pair in
            result + (pair.value.isDeleted ? 0 : 1)
        }
    }
    
    public init() {
        self.metadataByValue = [:]
        self.currentTimestamp = .init()
    }
    
    public init(array elements: [T]) {
        self = .init()
        elements.forEach { self.append($0) }
    }
    
    @discardableResult public mutating func insert(_ value: T, at index: Int) -> Bool {
        currentTimestamp.tick()
        
        let priority = updatePriorities(returningNewPriorityForInsertionAt: index)
        let metadata = Metadata(timestamp: currentTimestamp, orderPriority: priority)
        let isNewInsert: Bool
        
        if let oldMetadata = metadataByValue[value] {
            isNewInsert = oldMetadata.isDeleted
        } else {
            isNewInsert = true
        }
        metadataByValue[value] = metadata
        
        return isNewInsert
    }
    
    public mutating func append(_ value: T) {
        insert(value, at: count)
    }
    
    public mutating func move(_ value: T, toIndex index: Int) {
        guard contains(value) else { return }
        currentTimestamp.tick()
        
        let priority = updatePriorities(returningNewPriorityForInsertionAt: index)
        var metadata = metadataByValue[value]!
        metadata.timestamp = currentTimestamp
        metadata.orderPriority = priority
        metadataByValue[value] = metadata
    }
    
    @discardableResult public mutating func remove(_ value: T) -> T? {
        let returnValue: T?
    
        if let oldMetadata = metadataByValue[value], !oldMetadata.isDeleted {
            currentTimestamp.tick()
            var metadata = oldMetadata
            metadata.isDeleted = true
            metadata.timestamp = currentTimestamp
            metadataByValue[value] = metadata
            returnValue = value
        } else {
            returnValue = nil
        }
        
        return returnValue
    }
    
    public func contains(_ value: T) -> Bool {
        !(metadataByValue[value]?.isDeleted ?? true)
    }
}

extension MergeableOrderedSet {
    
    /// Calculates a priority value for inserting or moving an element to the specified index.
    /// Returns nil if a valid priority cannot be calculated due to:
    /// - Approaching maximum double precision when appending
    /// - Approaching minimum double precision when inserting at start
    /// - Insufficient precision between existing priorities when inserting between elements
    /// In these cases, the priorities should be normalized before trying again.
    private func calculatePriority(forInsertionAt index: Int) -> Double? {
        let values = self.values
        
        // Handle empty collection case
        if values.isEmpty {
            return 1.0
        }
        
        precondition(index >= 0 && index <= values.count, "Index out of bounds")
        
        if index == values.count {
            // Append at end
            let lastValue = values[values.count - 1]
            let lastPriority = metadataByValue[lastValue]!.orderPriority
            // Check if we're approaching max double precision
            if lastPriority > Double.greatestFiniteMagnitude / 2 {
                return nil
            }
            return lastPriority * 2
        } else if index == 0 {
            // Insert at start
            let firstValue = values[0]
            let firstPriority = metadataByValue[firstValue]!.orderPriority
            // Check if we're approaching minimum precision
            if firstPriority < Double.leastNonzeroMagnitude * 2 {
                return nil
            }
            return firstPriority / 2
        } else {
            // Insert between elements (requires at least 2 elements)
            precondition(values.count >= 2, "Inserting between elements requires at least 2 elements")
            let beforeValue = values[index - 1]
            let afterValue = values[index]
            let beforePriority = metadataByValue[beforeValue]!.orderPriority
            let afterPriority = metadataByValue[afterValue]!.orderPriority
            
            // Check if priorities are too close for precise midpoint
            if (afterPriority - beforePriority) < Double.leastNonzeroMagnitude * 2 {
                return nil
            }
            return (beforePriority + afterPriority) / 2
        }
    }
    
    /// Calculates a priority for insertion at the given index, normalizing all priorities if necessary.
    /// Will always return a valid priority value.
    private mutating func updatePriorities(returningNewPriorityForInsertionAt index: Int) -> Double {
        if let priority = calculatePriority(forInsertionAt: index) {
            return priority
        }
        normalizePriorities()
        return calculatePriority(forInsertionAt: index)!
    }
    
}

extension MergeableOrderedSet: ConflictFreeMergeable {
    
    public func merged(with other: Self) throws -> Self {
        var result = self
        result.metadataByValue = other.metadataByValue.reduce(into: metadataByValue) { result, entry in
            let firstMetadata = result[entry.key]
            let secondMetadata = entry.value
            if let firstMetadata {
                result[entry.key] = firstMetadata.timestamp > secondMetadata.timestamp ? firstMetadata : secondMetadata
            } else {
                result[entry.key] = secondMetadata
            }
        }
        result.currentTimestamp = Swift.max(self.currentTimestamp, other.currentTimestamp)
        
        // Only normalize if there are priority collisions
        if result.hasPriorityCollisions() {
            result.normalizePriorities()
        }
        
        return result
    }
    
    private func hasPriorityCollisions() -> Bool {
        let activePriorities = metadataByValue
            .filter { !$1.isDeleted }
            .map { $0.value.orderPriority }
        return Set(activePriorities).count != activePriorities.count
    }
    
    private mutating func normalizePriorities() {
        let activeElements = metadataByValue
            .filter { !$1.isDeleted }
            .sorted { pair1, pair2 in
                if pair1.value.orderPriority != pair2.value.orderPriority {
                    return pair1.value.orderPriority < pair2.value.orderPriority
                }
                return pair1.key < pair2.key
            }
        
        // Redistribute priorities evenly
        for (index, element) in activeElements.enumerated() {
            var metadata = element.value
            metadata.orderPriority = Double(index + 1) * 1000.0
            metadataByValue[element.key] = metadata
        }
    }
}

extension MergeableOrderedSet: Codable where T: Codable {}
extension MergeableOrderedSet.Metadata: Codable where T: Codable {}

extension MergeableOrderedSet: Equatable where T: Equatable {}
extension MergeableOrderedSet.Metadata: Equatable where T: Equatable {}

extension MergeableOrderedSet: Hashable where T: Hashable {}
extension MergeableOrderedSet.Metadata: Hashable where T: Hashable {}

extension MergeableOrderedSet: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: T...) {
        self = .init(array: elements)
    }
} 
