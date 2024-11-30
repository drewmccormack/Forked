import Foundation
import Forked

/// Merges an array by treating the contained elements as values.
public struct DictionaryMerger<Key: Hashable, Value: Equatable>: Merger {
    private typealias MergeableDict = MergeableDictionary<Key, Value>
    public init() {}
    
    public func merge(_ value: Dictionary<Key, Value>, withOlderConflicting other: Dictionary<Key, Value>, commonAncestor: Dictionary<Key, Value>?) throws -> Dictionary<Key, Value> {
        try merge(value, withOlderConflicting: other, commonAncestor: commonAncestor) { mergeableDict1, mergeableDict2, _ in
            try mergeableDict1.merged(with: mergeableDict2)
        }
    }

}

extension DictionaryMerger where Value: ConflictFreeMergeable {
    
    /// This overload is used when the value of the dictionary is `ConflictFreeMergeable`, and ensures that the contained values get merged properly.
    /// Without this, the contained values would be merged atomically.
    public func merge(_ value: Dictionary<Key, Value>, withOlderConflicting other: Dictionary<Key, Value>, commonAncestor: Dictionary<Key, Value>?) throws -> Dictionary<Key, Value> {
        try merge(value, withOlderConflicting: other, commonAncestor: commonAncestor) { mergeableDict1, mergeableDict2, _ in
            try mergeableDict1.merged(with: mergeableDict2)
        }
    }
    
}

extension DictionaryMerger where Value: Mergeable {
    
    /// This overload is used when the value of the dictionary is `Mergeable`, and ensures that the contained values get merged properly.
    /// Without this, the contained values would be merged atomically.
    /// This looks the same as the func for `Mergeable` types, but we need it so that the correct overload is chosen in `MergeableDictionary`
    public func merge(_ value: Dictionary<Key, Value>, withOlderConflicting other: Dictionary<Key, Value>, commonAncestor: Dictionary<Key, Value>?) throws -> Dictionary<Key, Value> {
        try merge(value, withOlderConflicting: other, commonAncestor: commonAncestor) { mergeableDict1, mergeableDict2, commonAncestorDict  in
            try mergeableDict1.merged(withOlderConflicting: mergeableDict2, commonAncestor: commonAncestorDict)
        }
    }
    
}

extension DictionaryMerger {
     
    private func merge(_ value: Dictionary<Key, Value>, withOlderConflicting other: Dictionary<Key, Value>, commonAncestor: Dictionary<Key, Value>?, mergeFunc: (_ value: MergeableDict, _ other: MergeableDict, _ ancestor: MergeableDict) throws -> MergeableDict) throws -> Dictionary<Key, Value> {
        guard let commonAncestor else { return value }
        
        // Update v1 last so it gets newer timestamps and is prioritized.
        let v0: MergeableDictionary<Key, Value> = .init(commonAncestor)
        var v1 = v0
        var v2 = v0
        update(mergeableDictionary: &v2, withDiffBetween: other, andAncestor: commonAncestor)
        update(mergeableDictionary: &v1, withDiffBetween: value, andAncestor: commonAncestor)
        
        return try mergeFunc(v1,v2,v0).dictionary
    }
    
    private func update(mergeableDictionary: inout MergeableDictionary<Key, Value>, withDiffBetween dict: Dictionary<Key, Value>, andAncestor commonAncestor: Dictionary<Key, Value>) {
        let inserted = Set(dict.keys).subtracting(commonAncestor.keys)
        let removed = Set(commonAncestor.keys).subtracting(dict.keys)
        let updated = Set(dict.keys).intersection(commonAncestor.keys).filter { dict[$0] != commonAncestor[$0] }
        for key in inserted {
            mergeableDictionary[key] = dict[key]
        }
        for key in removed {
            mergeableDictionary[key] = nil
        }
        for key in updated {
            mergeableDictionary[key] = dict[key]
        }
    }
    
}

