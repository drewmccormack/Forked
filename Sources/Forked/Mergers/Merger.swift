import Foundation

/// A merger is a type that applies a merging algorithm to merge two values together.
/// The values are typically of a simple type. The algorithm could be anything, from a
/// simple most recent edit wins, to more advanced CRDT based approaches that use
/// diffing against a common ancestor.
public protocol Merger {
    associatedtype T
    func merge(_ value: T, withOlderConflicting other: T, commonAncestor: T?) throws -> T
}

/// A Mergable type knows how to merge itself, so we just pass on the request and let it take care of it.
public struct MergableMerger<T: Mergable>: Merger {
    public func merge(_ value: T, withOlderConflicting other: T, commonAncestor: T?) throws -> T {
        try value.merged(withOlderConflicting: other, commonAncestor: commonAncestor)
    }
}
