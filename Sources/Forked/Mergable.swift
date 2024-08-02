import Foundation

public protocol Mergable {
    func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self
}
