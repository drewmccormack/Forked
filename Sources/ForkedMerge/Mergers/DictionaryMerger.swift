import Foundation
import Forked

/// Merges an array by treating the contained elements as values.
public struct DictionaryMerger<Key: Hashable, Value: Equatable>: Merger {
    private typealias MergeableDict = MergeableDictionary<Key, Value>
    public init() {}
}

extension DictionaryMerger {
    
    public func merge(_ value: Dictionary<Key, Value>, withSubordinate other: Dictionary<Key, Value>, commonAncestor: Dictionary<Key, Value>) throws -> Dictionary<Key, Value> {
        let v0: MergeableDictionary<Key, Value> = .init(commonAncestor)
        var v1 = v0
        var v2 = v0
        v2.dictionary = other
        v1.dictionary = value
        return try v1.merged(withSubordinate: v2, commonAncestor: v0).dictionary
    }
    
}

extension DictionaryMerger where Value: Mergeable {
    
    public func merge(_ value: Dictionary<Key, Value>, withSubordinate other: Dictionary<Key, Value>, commonAncestor: Dictionary<Key, Value>) throws -> Dictionary<Key, Value> {
        let v0: MergeableDictionary<Key, Value> = .init(commonAncestor)
        var v1 = v0
        var v2 = v0
        v2.dictionary = other
        v1.dictionary = value
        return try v1.merged(withSubordinate: v2, commonAncestor: v0).dictionary
    }
    
}

public func merge<Key, Value>(merger: DictionaryMerger<Key, Value>, dominant: Dictionary<Key, Value>, subordinate: Dictionary<Key, Value>, commonAncestor: Dictionary<Key, Value>) throws -> Dictionary<Key, Value> {
    return try merger.merge(dominant, withSubordinate: subordinate, commonAncestor: commonAncestor)
}

public func merge<Key, Value: Mergeable>(merger: DictionaryMerger<Key, Value>, dominant: Dictionary<Key, Value>, subordinate: Dictionary<Key, Value>, commonAncestor: Dictionary<Key, Value>) throws -> Dictionary<Key, Value> {
    return try merger.merge(dominant, withSubordinate: subordinate, commonAncestor: commonAncestor)
}
