import Foundation
import Forked

/// Merges an array, ensuring that the result has elements with unqiue identifiers.
public struct ArrayOfIdentifiableMerger<Element: Identifiable & Equatable>: Merger {
    public init() {}
}

extension ArrayOfIdentifiableMerger where Element: Mergeable {
    
    /// This function merges two arrays of elements that are identifiable and mergeable.
    /// The result is different to merging where the elements are not mergeable.
    /// This call will recurse the merge.
    public func merge(_ value: [Element], withSubordinate other: [Element], commonAncestor: [Element]) throws -> [Element] {
        let v0: MergeableArray<Element> = .init(commonAncestor)
        var v2 = v0
        var v1 = v0
        v2.values = other
        v1.values = value
        return try v1.merged(withSubordinate: v2, commonAncestor: v0).values
    }

}

extension ArrayOfIdentifiableMerger {
    
    /// This is the default for when the elements are note mergeable.
    public func merge(_ value: [Element], withSubordinate other: [Element], commonAncestor: [Element]) throws -> [Element] {
        let v0: MergeableArray<Element> = .init(commonAncestor)
        var v2 = v0
        var v1 = v0
        v2.values = other
        v1.values = value
        return try v1.merged(withSubordinate: v2, commonAncestor: v0).values
    }
    
}

