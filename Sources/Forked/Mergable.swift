import Foundation

public protocol Mergable {
    func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self
}

public protocol ConflictFreeMergable: Mergable {
    func merged(with other: Self) throws -> Self
}

public extension ConflictFreeMergable {
    func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
        try merged(with: other)
    }
}
