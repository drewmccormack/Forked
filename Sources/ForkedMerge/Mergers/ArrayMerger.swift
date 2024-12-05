import Foundation

/// Merges an array by treating the contained elements as values.
public struct ArrayMerger<Element: Equatable>: Merger {
    
    public init() {}

    public func merge(_ value: [Element], withSubordinate other: [Element], commonAncestor: [Element]) throws -> [Element] {
        let v0: MergeableArray<Element> = .init(commonAncestor)
        var v1 = v0
        var v2 = v0
        v2.values = other
        v1.values = value
        return try v1.merged(withSubordinate: v2, commonAncestor: v0).values
    }
    
}
