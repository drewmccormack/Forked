import Foundation

public protocol Mergeable {
    func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self
}

extension Optional: Mergeable where Wrapped: Mergeable & Equatable {
    
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
