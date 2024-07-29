import Foundation

/// This is storage of some sort for the resource. It could
/// be persisted on disk, or in memory.
public protocol Repository: AnyObject {
    var forks: [Fork] { get }
    func has(_ fork: Fork) -> Bool
    func content<R: ResourceValue>(for fork: Fork) throws -> ForkContent<R>
    func create(_ fork: Fork) throws
    func delete(_ fork: Fork) throws
    @discardableResult func update<R: ResourceValue>(_ fork: Fork, with content: ForkContent<R>) throws -> LamportTimestamp
    func mostRecentTimestamp(in fork: Fork) throws -> LamportTimestamp
    func mostAncientTimestamp(in fork: Fork) throws -> LamportTimestamp
}

public protocol ResourceValue: Equatable {}

public enum ForkContent<R: ResourceValue>: Equatable {
    case none
    case resourceValue(R)
}
