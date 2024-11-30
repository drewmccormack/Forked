import Foundation

/// Merges an array by treating the contained elements as values.
public struct SetMerger<Element: Hashable>: Merger {
    
    public init() {}

    public func merge(_ value: Set<Element>, withOlderConflicting other: Set<Element>, commonAncestor: Set<Element>?) throws -> Set<Element> {
        guard let commonAncestor else { return value }
        
        // Update v1 last so it gets newer timestamps and is prioritized.
        var v1: MergeableSet<Element> = .init(commonAncestor)
        var v2 = v1
        v2.values = other
        v1.values = value

        return try v1.merged(with: v2).values
    }
    
}
