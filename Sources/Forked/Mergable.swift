import Foundation

public protocol Mergable: Equatable {
    func merged(withConflicting other: Self, commonAncestor: Self) -> Self
}
