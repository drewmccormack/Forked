import Foundation
import Forked

/// A merger is a type that applies a merging algorithm to merge two values together.
/// The values are typically of a simple type. The algorithm could be anything, from a
/// simple most recent edit wins, to more advanced CRDT based approaches that use
/// diffing against a common ancestor.
public protocol Merger {
    associatedtype T
    init()
    func merge(_ value: T, withSubordinate other: T, commonAncestor: T) throws -> T
}

public func merge<M: Merger>(withMergerType: M.Type, dominant: M.T, subordinate: M.T, commonAncestor: M.T) throws -> M.T {
    let merger = M()
    return try merger.merge(dominant, withSubordinate: subordinate, commonAncestor: commonAncestor)
}

public func merge<M: Merger>(withMergerType: M.Type, dominant: M.T?, subordinate: M.T?, commonAncestor: M.T?) throws -> M.T? {
    switch (dominant, subordinate, commonAncestor) {
    case let (dominant?, subordinate?, commonAncestor?):
        return try merge(withMergerType: M.self, dominant: dominant, subordinate: subordinate, commonAncestor: commonAncestor)
    case (nil, nil, _):
        return nil
    case let (dominant?, _, _):
        return dominant
    case let (nil, subordinate?, _):
        return subordinate
    }
}

public func merge<M: Merger>(withMergerType: M.Type, dominant: M.T?, subordinate: M.T?, commonAncestor: M.T?) throws -> M.T? where M.T: Equatable {
    switch (dominant, subordinate, commonAncestor) {
    case let (dominant?, subordinate?, commonAncestor?):
        return try merge(withMergerType: M.self, dominant: dominant, subordinate: subordinate, commonAncestor: commonAncestor)
    case (nil, nil, _):
        return nil
    case let (dominant?, nil, nil):
        return dominant
    case let (dominant?, nil, commonAncestor?):
        return dominant != commonAncestor ? dominant : nil
    case let (nil, subordinate?, nil):
        return subordinate
    case let (nil, subordinate?, commonAncestor?):
        return subordinate != commonAncestor ? subordinate : nil
    case let (dominant?, .some, nil):
        return dominant
    }
}
