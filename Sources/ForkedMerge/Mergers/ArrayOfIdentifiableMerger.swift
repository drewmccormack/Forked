import Foundation
import Forked

/// Merges an array, ensuring that the result has elements with unqiue identifiers.
public struct ArrayOfIdentifiableMerger<Element: Identifiable & Equatable>: Merger {
    public init() {}
    
    public func merge(_ value: [Element], withOlderConflicting other: [Element], commonAncestor: [Element]?) throws -> [Element] {
        try merge(value, withOlderConflicting: other, commonAncestor: commonAncestor) { mergeableArray1, mergeableArray2, _ in
            try mergeableArray1.merged(with: mergeableArray2)
        }
    }
}

extension ArrayOfIdentifiableMerger where Element: ConflictFreeMergeable {
    
    /// This overload is used when the value of the array element is `ConflictFreeMergeable`, and ensures that the contained values get merged properly.
    /// Without this, the contained values would be merged atomically.
    public func merge(_ value: [Element], withOlderConflicting other: [Element], commonAncestor: [Element]?) throws -> [Element] {
        try merge(value, withOlderConflicting: other, commonAncestor: commonAncestor) { mergeableArray1, mergeableArray2, _ in
            try mergeableArray1.merged(with: mergeableArray2)
        }
    }
    
}

extension ArrayOfIdentifiableMerger where Element: Mergeable {
    
    /// This overload is used when the elements are `Mergeable`, and ensures that the contained values get merged properly.
    /// Without this, the contained values would be merged atomically.
    /// This looks the same as the func for `ConflictFreeMergeable` types, but we need it so that the correct overload is chosen in `MergeableArray`
    public func merge(_ value: [Element], withOlderConflicting other: [Element], commonAncestor: [Element]?) throws -> [Element] {
        try merge(value, withOlderConflicting: other, commonAncestor: commonAncestor) { mergeableArray1, mergeableArray2, mergeableArrayAncestor  in
            try mergeableArray1.merged(withOlderConflicting: mergeableArray2, commonAncestor: mergeableArrayAncestor)
        }
    }
    
}

extension ArrayOfIdentifiableMerger {

    public func merge(_ value: [Element], withOlderConflicting other: [Element], commonAncestor: [Element]?, mergeFunc: (_ value: MergeableArray<Element>, _ other: MergeableArray<Element>, _ ancestor: MergeableArray<Element>) throws -> MergeableArray<Element>) throws -> [Element] {
        guard let commonAncestor else { return value }
        let v0: MergeableArray<Element> = .init(commonAncestor)
        var v2 = v0
        var v1 = v0
        v2.values = other
        v1.values = value
        return try mergeFunc(v1,v2,v0).entriesUniquelyIdentified().values
    }
    
}

