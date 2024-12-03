import Foundation

/// Merges an array, ensuring that the result has elements with unqiue identifiers.
public struct ArrayOfIdentifiableMerger<Element: Identifiable & Equatable>: Merger {
    
    public init() {}

    public func merge(_ value: [Element], withOlderConflicting other: [Element], commonAncestor: [Element]?) throws -> [Element] {
        guard let commonAncestor else { return value }
        var v1: MergeableArray<Element> = .init(commonAncestor)
        var v2 = v1
        v2.values = other
        v1.values = value
        return v1.merged(with: v2).entriesUniquelyIdentified().values
    }
    
}

