import Foundation
import Forked

/// Represents a mergable type for a dictionary of values.
/// Uses a CRDT algorithm.
public struct MergeableDictionary<Key, Value> where Key: Hashable {
    
    fileprivate struct ValueContainer {
        var isDeleted: Bool
        var timestamp: StableTimestamp
        var value: Value
        
        init(value: Value, timestamp: StableTimestamp) {
            self.isDeleted = false
            self.timestamp = timestamp
            self.value = value
        }
    }
    
    private var valueContainersByKey: Dictionary<Key, ValueContainer>
    private var currentTimestamp: StableTimestamp
    
    private var existingKeyValuePairs: [(key: Key, value: ValueContainer)] {
        valueContainersByKey.filter({ !$0.value.isDeleted })
    }
    
    public var values: [Value] {
        let values = existingKeyValuePairs.map({ $0.value.value })
        return values
    }
    
    public var keys: [Key] {
        let keys = existingKeyValuePairs.map({ $0.key })
        return keys
    }
    
    public var dictionary: [Key : Value] {
        existingKeyValuePairs.reduce(into: [:]) { result, pair in
            result[pair.key] = pair.value.value
        }
    }
    
    public var count: Int {
        valueContainersByKey.reduce(0) { result, pair in
            result + (pair.value.isDeleted ? 0 : 1)
        }
    }
        
    public init() {
        self.valueContainersByKey = .init()
        self.currentTimestamp = .init()
    }
    
    public init(_ other: Dictionary<Key, Value>) {
        self.init()
        for (k,v) in other {
            self[k] = v
        }
    }
    
    public subscript(key: Key) -> Value? {
        get {
            guard let container = valueContainersByKey[key], !container.isDeleted else { return nil }
            return container.value
        }
        
        set(newValue) {
            currentTimestamp.tick()
            if let newValue = newValue {
                let container = ValueContainer(value: newValue, timestamp: currentTimestamp)
                valueContainersByKey[key] = container
            } else if let oldContainer = valueContainersByKey[key] {
                var newContainer = ValueContainer(value: oldContainer.value, timestamp: currentTimestamp)
                newContainer.isDeleted = true
                valueContainersByKey[key] = newContainer
            }
        }
    }
}

extension MergeableDictionary: ExpressibleByDictionaryLiteral {
    
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.init()
        for (k,v) in elements {
            self[k] = v
        }
    }
    
}

extension MergeableDictionary: ConflictFreeMergeable {
    
    public func merged(with other: MergeableDictionary) throws -> MergeableDictionary {
        try mergedNonRecursively(with: other)
    }
    
    private func mergedNonRecursively(with other: MergeableDictionary) throws -> MergeableDictionary {
        var result = self
        result.valueContainersByKey = other.valueContainersByKey.reduce(into: valueContainersByKey) { result, entry in
            let firstValueContainer = result[entry.key]
            let secondValueContainer = entry.value
            if let firstValueContainer = firstValueContainer {
                result[entry.key] = firstValueContainer.timestamp > secondValueContainer.timestamp ? firstValueContainer : secondValueContainer
            } else {
                result[entry.key] = secondValueContainer
            }
        }
        result.currentTimestamp = max(self.currentTimestamp, other.currentTimestamp)
        return result
    }
    
}

extension MergeableDictionary where Value: ConflictFreeMergeable {
    
    /// If the values are themselves ConflictFreeMergeable, we don't have to merge values atomically.
    /// Instead of just choosing one value or the other, we can merge the values themselves. This merge
    /// method does exactly that.
    /// You get a recursive merge, as the dictionary merges, but also the values in the dictionary
    public func merged(with other: Self) throws -> Self {
        var haveTicked = false
        var resultDictionary = self
        resultDictionary.currentTimestamp = max(self.currentTimestamp, other.currentTimestamp)
        resultDictionary.valueContainersByKey = try other.valueContainersByKey.reduce(into: valueContainersByKey) { result, entry in
            let first = result[entry.key]
            let second = entry.value
            if let first = first {
                if !first.isDeleted, !second.isDeleted {
                    // Merge the values
                    if !haveTicked {
                        resultDictionary.currentTimestamp.tick()
                        haveTicked = true
                    }
                    let newValue = try first.value.merged(with: second.value)
                    let newValueContainer = ValueContainer(value: newValue, timestamp: resultDictionary.currentTimestamp)
                    result[entry.key] = newValueContainer
                } else {
                    // At least one deletion, so just revert to atomic merge
                    result[entry.key] = first.timestamp > second.timestamp ? first : second
                }
            } else {
                result[entry.key] = second
            }
        }
        return resultDictionary
    }
    
    func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
        try merged(with: other)
    }
    
}

extension MergeableDictionary where Value: Mergeable {
    
    /// Even though the values contained are mergable, they don't support conflict-free merging.
    /// This means they will be merged atomically. If you want the values themselves to be merged,
    /// call the 3-way merge func, ie `merged(withOlderConflicting:commonAncestor:)`
    public func merged(with other: Self) throws -> Self {
        try mergedNonRecursively(with: other)
    }
    
    /// If the values are themselves Mergeable, but not conflict-free, we can only use 3-way merge with common ancestor.
    /// You get a recursive merge, as the dictionary merges, but also the values in the dictionary
    public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
        var haveTicked = false
        var resultDictionary = self
        resultDictionary.currentTimestamp = max(self.currentTimestamp, other.currentTimestamp)
        resultDictionary.valueContainersByKey = try other.valueContainersByKey.reduce(into: valueContainersByKey) { result, entry in
            let first = result[entry.key]
            let second = entry.value
            if let first {
                if !first.isDeleted, !second.isDeleted {
                    // Merge the values
                    if !haveTicked {
                        resultDictionary.currentTimestamp.tick()
                        haveTicked = true
                    }
                    let ancestor = commonAncestor?.valueContainersByKey[entry.key]
                    let newValue = try first.value.merged(withOlderConflicting: second.value, commonAncestor: ancestor?.value)
                    let newValueContainer = ValueContainer(value: newValue, timestamp: resultDictionary.currentTimestamp)
                    result[entry.key] = newValueContainer
                } else {
                    // At least one deletion, so just revert to atomic merge
                    result[entry.key] = first.timestamp > second.timestamp ? first : second
                }
            } else {
                result[entry.key] = second
            }
        }
        return resultDictionary
    }
    
}

extension MergeableDictionary: Codable where Value: Codable, Key: Codable {}
extension MergeableDictionary.ValueContainer: Codable where Value: Codable, Key: Codable {}

extension MergeableDictionary: Equatable where Value: Equatable {}
extension MergeableDictionary.ValueContainer: Equatable where Value: Equatable {}

extension MergeableDictionary: Hashable where Value: Hashable {}
extension MergeableDictionary.ValueContainer: Hashable where Value: Hashable {}
