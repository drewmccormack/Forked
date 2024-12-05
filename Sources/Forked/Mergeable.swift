import Foundation

public protocol Mergeable {
    func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self
}
