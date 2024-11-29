import Foundation
import Forked

/// Merges an array by treating the contained elements as values.
public struct DictionaryMerger<Key: Hashable, Value: Equatable>: Merger {
    private typealias MergeableDict = MergeableDictionary<Key, Value>
    public init() {}
    
    public func merge(_ value: Dictionary<Key, Value>, withOlderConflicting other: Dictionary<Key, Value>, commonAncestor: Dictionary<Key, Value>?) throws -> Dictionary<Key, Value> {
        try merge(value, withOlderConflicting: other, commonAncestor: commonAncestor) { v1, v2 in
            try v1.merged(with: v2)
        }
    }
    
    private func merge(_ value: Dictionary<Key, Value>, withOlderConflicting other: Dictionary<Key, Value>, commonAncestor: Dictionary<Key, Value>?, mergeFunc: (MergeableDict, MergeableDict) throws -> MergeableDict) throws -> Dictionary<Key, Value> {
        guard let commonAncestor else { return value }

        // Update v1 last so it gets newer timestamps and is prioritized.
        var v1: MergeableDictionary<Key, Value> = .init(commonAncestor)
        var v2 = v1
        update(mergeableDictionary: &v2, withDiffBetween: other, andAncestor: commonAncestor)
        update(mergeableDictionary: &v1, withDiffBetween: value, andAncestor: commonAncestor)

        return try mergeFunc(v1,v2).dictionary
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

extension DictionaryMerger where Value: Mergeable {
    
    /// This overload is used when the value of the dictionary is `Mergeable`, and ensures that the contained values get merged.
    public func merge(_ value: Dictionary<Key, Value>, withOlderConflicting other: Dictionary<Key, Value>, commonAncestor: Dictionary<Key, Value>?) throws -> Dictionary<Key, Value> {
        try merge(value, withOlderConflicting: other, commonAncestor: commonAncestor) { v1, v2 in
            try v1.merged(with: v2)
        }
    }
    
}
