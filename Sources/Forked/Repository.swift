import Foundation

public protocol Persistent: Repository {
    /// If needed, the repo can store data persistently at this point (or do nothing)
    /// Do not call this unless you are using a type that is persistable, otherwise you
    /// will get a fatalError.
    func persist() throws
    
    /// Loads repo from storage if this is a persistable repo.
    /// Do not call this unless you are using a type that is persistable, otherwise you
    /// will get a fatalError.
    func load() throws
}

/// This is storage for the `ForkedResource`. It could
/// be persisted on disk, or just kept in memory.
/// This type does not understand any of the mechanisms of forking
/// and merging. That is all handled by the `ForkedResource`, which also
/// ensures correct multi-threading behavior.
/// Classes conforming to this type simply have to setup a storage
/// mechanism, and handle the requests, keeping commits assigned to forks.
public protocol Repository: AnyObject {
    associatedtype Resource: Equatable
    
    /// The forks in the repository, including .main, in no particular order.
    var forks: [Fork] { get }
    
    /// Creates a fork providing an initial commit to populate it with.
    /// Throws if the fork is already present.
    func create(_ fork: Fork, withInitialCommit commit: Commit<Resource>) throws
    
    /// Delete an existing fork. Throws if it isn't present.
    func delete(_ fork: Fork) throws
    
    /// All versions stored in a given fork. There will usually be 0, 1 or 2,
    /// though there may be temporaily more.
    /// Note that this is just the versions stored for the fork. The interpretation
    /// of the stored versions is handled by the `ForkedResource`. For example,
    /// if there are no versions in the fork of the repo, the `ForkedResource`
    /// will assume it is at the same version as stored in the main fork.
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

public extension Persistent {
    
    func persist() throws {
        fatalError("Persist not implemented for \(Self.self)")
    }
    
    func load() throws {
        fatalError("load not implemented for \(Self.self)")
    }
    
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
    
    /// Returns the occupation state of a fork based on its stored commits.
    /// - If there are no commits, the fork is considered the same as main
    /// - If there is one commit, that commit is both the current value and common ancestor (fork is behind main)
    /// - If there are two commits, the oldest is the common ancestor and newest is the current value
    /// - If there are more than two commits, only the oldest (ancestor) and newest (current) are relevant
    func occupation(of fork: Fork) throws -> ForkOccupation<Resource> {
        guard fork != .main else { return .sameAsMain }
        
        let versions = try ascendingVersions(storedIn: fork)
        
        switch versions.count {
        case 0:
            return .sameAsMain
            
        case 1:
            // Single commit means fork is behind main
            let version = versions.first!
            let content = try content(of: fork, at: version)
            let commit = Commit(content: content, version: version)
            return .leftBehindByMain(commit)
            
        case 2...:
            // Two or more commits - oldest is ancestor, newest is current
            let ancestorVersion = versions.first!
            let currentVersion = versions.last!
            
            let ancestorContent = try content(of: fork, at: ancestorVersion)
            let currentContent = try content(of: fork, at: currentVersion)
            
            let ancestorCommit = Commit(content: ancestorContent, version: ancestorVersion)
            let currentCommit = Commit(content: currentContent, version: currentVersion)
            
            return .aheadOrConflictingWithMain(currentCommit, commonAncestor: ancestorCommit)
            
        default:
            fatalError("Negative count of versions should be impossible")
        }
    }
    
    /// Removes any commits that are neither the ancestor nor the current commit.
    /// For the main fork, only keeps the most recent commit.
    /// For other forks:
    /// - If empty or one commit, does nothing
    /// - If two or more commits, keeps only the oldest (ancestor) and newest (current)
    func removeRedundantCommits(from fork: Fork) throws {
        let versions = try ascendingVersions(storedIn: fork)
        
        if fork == .main {
            // Main fork only needs most recent commit
            let versionsToRemove = versions.dropLast()
            for version in versionsToRemove {
                try removeCommit(at: version, from: fork)
            }
            return
        }
        
        // For other forks with more than 2 commits,
        // remove everything except oldest (ancestor) and newest (current)
        if versions.count > 2 {
            let versionsToKeep = Set([versions.first!, versions.last!])
            for version in versions where !versionsToKeep.contains(version) {
                try removeCommit(at: version, from: fork)
            }
        }
    }
}
