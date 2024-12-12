import Foundation

public func areEqualForForked<T>(_ lhs: T, _ rhs: T) -> Bool {
    return false
}

public func areEqualForForked<T: Equatable>(_ lhs: T, _ rhs: T) -> Bool {
    return lhs == rhs
}
