import Foundation

/// Merges an array by treating the contained elements as values.
public struct ArrayMerger<Element: Equatable>: Merger {
    
    public init() {}

    public func merge(_ value: [Element], withOlderConflicting other: [Element], commonAncestor: [Element]?) throws -> [Element] {
        guard let commonAncestor else { return value }
        var v1: MergeableArray<Element> = .init(commonAncestor)
        var v2 = v1
        v2.values = other
        v1.values = value
        return v1.merged(with: v2).values
    }
    
}
