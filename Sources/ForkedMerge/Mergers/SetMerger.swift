import Foundation

/// Merges a set by treating the contained elements as values.
public struct SetMerger<Element: Hashable>: Merger {
    
    public init() {}

    public func merge(_ value: Set<Element>, withSubordinate other: Set<Element>, commonAncestor: Set<Element>) throws -> Set<Element> {        
        // Update v1 last so it gets newer timestamps and is prioritized.
        let v0: MergeableSet<Element> = .init(commonAncestor)
        var v1 = v0
        var v2 = v0
        v2.values = other
        v1.values = value

        return try v1.merged(withSubordinate: v2, commonAncestor: v0).values
    }
    
}
