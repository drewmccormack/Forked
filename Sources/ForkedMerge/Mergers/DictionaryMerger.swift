import Foundation

/// Merges an array by treating the contained elements as values.
public struct DictionaryMerger<Key: Hashable, Value: Equatable>: Merger {
    
    public init() {}

    public func merge(_ value: Dictionary<Key, Value>, withOlderConflicting other: Dictionary<Key, Value>, commonAncestor: Dictionary<Key, Value>?) throws -> Dictionary<Key, Value> {
        guard let commonAncestor else { return value }
        
        func update(with dict: Dictionary<Key, Value>, mergeableDictionary: inout MergeableDictionary<Key, Value>) {
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

        // Update v1 last so it gets newer timestamps and is prioritized.
        var v1: MergeableDictionary<Key, Value> = .init(commonAncestor)
        var v2 = v1
        update(with: other, mergeableDictionary: &v2)
        update(with: value, mergeableDictionary: &v1)

        return try v1.merged(with: v2).dictionary
    }
    
}
