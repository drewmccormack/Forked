import Foundation
import Forked

/// A merger is a type that applies a merging algorithm to merge two values together.
/// The values are typically of a simple type. The algorithm could be anything, from a
/// simple most recent edit wins, to more advanced CRDT based approaches that use
/// diffing against a common ancestor.
public protocol Merger {
    associatedtype T
    func merge(_ value: T, withSubordinate other: T, commonAncestor: T) throws -> T
}
