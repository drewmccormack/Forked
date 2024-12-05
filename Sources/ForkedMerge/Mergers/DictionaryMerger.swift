import Foundation
import Forked

/// Merges an array by treating the contained elements as values.
public struct DictionaryMerger<Key: Hashable, Value: Equatable>: Merger {
    private typealias MergeableDict = MergeableDictionary<Key, Value>
    public init() {}
    
    public func merge(_ value: Dictionary<Key, Value>, withSubordinate other: Dictionary<Key, Value>, commonAncestor: Dictionary<Key, Value>) throws -> Dictionary<Key, Value> {
        try merge(value, withSubordinate: other, commonAncestor: commonAncestor) { mergeableDict1, mergeableDict2, commonAncestorDict in
            try mergeableDict1.merged(withSubordinate: mergeableDict2, commonAncestor: commonAncestorDict)
        }
    }

}

extension DictionaryMerger where Value: Mergeable {
    
    /// This overload is used when the value of the dictionary is `Mergeable`, and ensures that the contained values get merged properly.
    /// Without this, the contained values would be merged atomically.
    public func merge(_ value: Dictionary<Key, Value>, withSubordinate other: Dictionary<Key, Value>, commonAncestor: Dictionary<Key, Value>) throws -> Dictionary<Key, Value> {
        try merge(value, withSubordinate: other, commonAncestor: commonAncestor) { mergeableDict1, mergeableDict2, commonAncestorDict  in
            try mergeableDict1.merged(withSubordinate: mergeableDict2, commonAncestor: commonAncestorDict)
        }
    }
    
}

extension DictionaryMerger {
     
    private func merge(_ value: Dictionary<Key, Value>, withSubordinate other: Dictionary<Key, Value>, commonAncestor: Dictionary<Key, Value>, mergeFunc: (_ value: MergeableDict, _ other: MergeableDict, _ ancestor: MergeableDict) throws -> MergeableDict) throws -> Dictionary<Key, Value> {        
        // Update v1 last so it gets newer timestamps and is prioritized.
        let v0: MergeableDictionary<Key, Value> = .init(commonAncestor)
        var v1 = v0
        var v2 = v0
        v2.dictionary = other
        v1.dictionary = value
        return try mergeFunc(v1,v2,v0).dictionary
    }
    
}

