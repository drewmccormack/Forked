import Foundation

/// This is storage of some sort for the resource. It could
/// be persisted on disk, or in memory.
public protocol Repository: AnyObject {
    associatedtype ResourceValueType: Resource
    
    var forks: [Fork] { get }
    func has(_ fork: Fork) -> Bool

    func create(_ fork: Fork) throws
    func delete(_ fork: Fork) throws
    
    func versions(storedIn fork: Fork) throws -> [Version]
    func content(of fork: Fork, at version: Version) throws -> CommitContent<ResourceValueType>
    
    func store(_ commit: Commit<ResourceValueType>, in fork: Fork) throws
    func removeCommit(at version: Version, from fork: Fork) throws
    
}

extension Repository {
    
    func mostRecentVersion() throws -> Version {
        try forks.flatMap { try versions(storedIn: $0) }.max()!
    }
}
