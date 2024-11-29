import Foundation

/// Merges an array by treating the contained elements as values.
public struct SetMerger<Element: Hashable>: Merger {
    
    public init() {}

    public func merge(_ value: Set<Element>, withOlderConflicting other: Set<Element>, commonAncestor: Set<Element>?) throws -> Set<Element> {
        guard let commonAncestor else { return value }
        
        func mergeableSet(for newSet: Set<Element>, mergeableSet: inout MergeableSet<Element>) {
            let inserted = newSet.subtracting(commonAncestor)
            let removed = commonAncestor.subtracting(newSet)
            for value in inserted {
                mergeableSet.insert(value)
            }
            for value in removed {
                mergeableSet.remove(value)
            }
            return
        }

        var v1: MergeableSet<Element> = .init(commonAncestor)
        var v2 = v1
        mergeableSet(for: value, mergeableSet: &v1)
        mergeableSet(for: other, mergeableSet: &v2)
        
        return try v1.merged(with: v1).values
    }
    
}
