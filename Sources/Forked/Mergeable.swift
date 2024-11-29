import Foundation

public protocol Mergeable {
    func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self
}

public protocol ConflictFreeMergeable: Mergeable {
    func merged(with other: Self) throws -> Self
}

public extension ConflictFreeMergeable {
    func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
        try merged(with: other)
    }
}
