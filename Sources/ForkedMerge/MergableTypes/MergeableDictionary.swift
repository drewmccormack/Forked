import Foundation
import Forked

/// Represents a mergable type for a dictionary of values.
/// Uses a CRDT algorithm.
public struct MergeableDictionary<Key:Hashable, Value: Equatable>: Equatable {
    
    fileprivate struct ValueContainer: Equatable {
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
        get {
            existingKeyValuePairs.reduce(into: [:]) { result, pair in
                result[pair.key] = pair.value.value
            }
        }
        set {
            let oldValue = dictionary
            let oldKeys = Set(keys)
            let newKeys = Set(newValue.keys)
            let inserted = newKeys.subtracting(oldKeys)
            let removed = Set(oldKeys).subtracting(newKeys)
            let updated = newKeys.intersection(oldKeys).filter { newValue[$0] != oldValue[$0] }
            for key in inserted {
                self[key] = newValue[key]
            }
            for key in removed {
                self[key] = nil
            }
            for key in updated {
                self[key] = newValue[key]
            }
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

extension MergeableDictionary: Mergeable {
    
    /// This is a non-recursive version used when the values are not mergeable.
    public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
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

extension MergeableDictionary where Value: Mergeable {
    
    /// If the values are themselves Mergeable, but not conflict-free, we can only use 3-way merge with common ancestor.
    /// You get a recursive merge, as the dictionary merges, but also the values in the dictionary
    public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
        var haveTicked = false
        var resultDictionary = self
        resultDictionary.currentTimestamp = max(self.currentTimestamp, other.currentTimestamp)
        resultDictionary.valueContainersByKey = try other.valueContainersByKey.reduce(into: valueContainersByKey) { result, entry in
            let first = result[entry.key]
            let second = entry.value
            let ancestor = commonAncestor.valueContainersByKey[entry.key]
            if let first {
                if !first.isDeleted, !second.isDeleted, let ancestor, !ancestor.isDeleted {
                    // Merge the values
                    if !haveTicked {
                        resultDictionary.currentTimestamp.tick()
                        haveTicked = true
                    }
                    let newValue = try first.value.merged(withSubordinate: second.value, commonAncestor: ancestor.value)
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

extension MergeableDictionary: Hashable where Value: Hashable {}
extension MergeableDictionary.ValueContainer: Hashable where Value: Hashable {}
