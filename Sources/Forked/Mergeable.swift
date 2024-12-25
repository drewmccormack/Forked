import Foundation

/// Any type conforming to this can be used in a 3-way merge
public protocol Mergeable: Equatable {
    
    /// Performs a 3-way merge, where `self` and `other` are the most recent versions,
    /// and `commonAncestor` is from a point in the past at which time the histories diverged.
    /// By comparing the recent values to the ancestor, you can determine what changed in each fork,
    /// and decide how to merge. Where it is not possible to merge changes from each, `self` should
    /// be considered the `dominant` fork, and `other` subordinate. If you must choose, choose `self`.
    func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self
    
}

extension Optional: Mergeable where Wrapped: Mergeable {
    
    public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
        if self == commonAncestor {
            return other
        } else if other == commonAncestor {
            return self
        } else {
            // Conflicting changes
            switch (self, other, commonAncestor) {
            case (.none, .none, _):
                return .none
            case (.some(let s), .none, _):
                return s
            case (.none, .some(let o), _):
                return o
            case (.some(let s), .some(let o), .some(let c)):
                return try s.merged(withSubordinate: o, commonAncestor: c)
            case (.some(let s), .some, .none):
                return s
            }
        }
    }
    
}

extension Optional: @retroactive Identifiable where Wrapped: Identifiable {
    
    public var id: Wrapped.ID? {
        self?.id
    }
    
}
