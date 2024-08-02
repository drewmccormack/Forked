import Foundation

/// This is storage for the `ForkedResource`. It could
/// be persisted on disk, or just kept in memory.
/// This type does not understand any of the mechanisms of forking
/// and merging. That is all handled by the `ForkedResource`, which also
/// ensures correct multi-threading behavior.
/// Classes conforming to this type simply have to setup a storage
/// mechanism, and handle the requests, keeping commits assigned to forks.
public protocol Repository: AnyObject {
    associatedtype Resource
    
    /// The forks in the repository, including .main, in no particular order.
    var forks: [Fork] { get }

    /// Creates a fork providing an initial commit to populate it with.
    /// Throws if the fork is already present.
    func create(_ fork: Fork, withInitialCommit commit: Commit<Resource>) throws
    
    /// Delete an existing fork. Throws if it isn't present.
    func delete(_ fork: Fork) throws
    
    /// All versions stored in a given fork. There can be 0, 1 or 2.
    /// Note that this is just the versions stored for the fork. The interpretation
    /// of the stored versions is handled by the `ForkedResource`. For example,
    /// if there are no versions in the fork of the repo, the `ForkedResource`
    /// will assume it is at the version stored in the main fork.
    func versions(storedIn fork: Fork) throws -> Set<Version>
    
    /// Get the content from the repo with the version passed. If not found,
    /// it will throw an error.
    func content(of fork: Fork, at version: Version) throws -> CommitContent<Resource>
    
    /// Store a version of the resource in a fork. The fork must exist, and the
    /// version must not already be in the fork, otherwise an error is thrown.
    func store(_ commit: Commit<Resource>, in fork: Fork) throws
    
    /// Remove a commit for a given version from the fork. If the version is
    /// not found, an error is thrown.
    func removeCommit(at version: Version, from fork: Fork) throws
}

extension Repository {
    /// Versions in ascending order, from oldest to newest
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
    
    /// Copies the most recent commit found in a fork to another fork.
    /// If there is no commit in the fork, an error is thrown.
    /// If the version already exists in the destination fork, an error is thrown
    func copyMostRecentCommit(from fromFork: Fork, to toFork: Fork) throws {
        guard fromFork != toFork else { return }
        guard let fromVersion = try mostRecentVersion(storedIn: fromFork) else {
            throw Error.attemptToAccessNonExistentCommitInFork(fromFork)
        }
        let content = try content(of: fromFork, at: fromVersion)
        let commit: Commit<Resource> = .init(content: content, version: fromVersion)
        try store(commit, in: toFork)
    }
}
