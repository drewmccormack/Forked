import Foundation

/// This is storage of some sort for the resource. It could
/// be persisted on disk, or in memory.
/// This type does not understand any of the mechanisms of forking
/// and merging. That is all handled by the ForkedResource, which also
/// ensures correct multi-threading behavior.
/// Classes conforming to this type simply have to setup some sort of storage
/// mechanism, and handle the requests.
public protocol Repository: AnyObject {
    associatedtype ResourceType: Resource
    
    var forks: [Fork] { get }

    func create(_ fork: Fork) throws
    func delete(_ fork: Fork) throws
    
    func versions(storedIn fork: Fork) throws -> Set<Version>
    func content(of fork: Fork, at version: Version) throws -> CommitContent<ResourceType>
    
    func store(_ commit: Commit<ResourceType>, in fork: Fork) throws
    func removeCommit(at version: Version, from fork: Fork) throws
}

extension Repository {
    func ascendingVersions(storedIn fork: Fork) throws -> [Version] {
        try versions(storedIn: fork).sorted()
    }
    
    /// The most recent version anywhere in the repo,
    func mostRecentVersion() throws -> Version {
        try forks.flatMap { try versions(storedIn: $0) }.max()!
    }
    
    /// The most recent commit in a fork, if there is any. A fork can be empty, such
    /// as when it has the same version as the main fork. In this case, it should return nil.
    func mostRecentVersion(storedIn fork: Fork) throws -> Version? {
        try versions(storedIn: fork).max()
    }
    
    func copyMostRecentCommit(from fromFork: Fork, to toFork: Fork) throws {
        guard fromFork != toFork else { return }
        guard let fromVersion = try mostRecentVersion(storedIn: fromFork) else {
            throw Error.attemptToAccessNonExistentCommitInFork(fromFork)
        }
        let content = try content(of: fromFork, at: fromVersion)
        let commit: Commit<ResourceType> = .init(content: content, version: fromVersion)
        try store(commit, in: toFork)
    }
}
