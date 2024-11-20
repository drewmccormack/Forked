import Foundation

public extension ForkedResource {
    
    /// Whether a fork exists in the `ForkedResource`
    func has(_ fork: Fork) -> Bool {
        serialize {
            repository.forks.contains(fork)
        }
    }
    
    /// All forks in the resource, including the main fork, in no particular order
    var forks: [Fork] {
        serialize {
            repository.forks
        }
    }
    
    /// If you want to perform a series of calls as a single transaction,
    /// preventing other threads from changing anything between calls,
    /// use this to group the transaction of calls. Note that reentrance of this
    /// method from the same thread will lead to deadlock. It is best not to
    /// execute long running code in the block, because all other interactions
    /// with the `ForkedResource` will block waiting.
    func performAtomically(_ block: () throws -> Void) throws {
        try serialize {
            try block()
        }
    }
    
    /// Returns the most recent (current) version of the `Fork`. Note that this may
    /// not actually be from a commit in the corresponding fork of the repository.
    /// In particular, if a repository fork is empty, it is considered to share the same
    /// version as the main fork, and the main fork version will be returned.
    func mostRecentVersion(of fork: Fork) throws -> Version {
        try serialize {
            guard has(fork) else { throw Error.attemptToAccessNonExistentFork(fork) }
            return
                try repository.mostRecentVersion(storedIn: fork) ??
                repository.mostRecentVersion(storedIn: .main)!
        }
    }
    
    /// The most recent (current) version of the main fork.
    func mostRecentVersionOfMain() throws -> Version {
        try mostRecentVersion(of: .main)
    }
    
    /// This reads the repo, determining the most recent commit associated with the fork.
    /// Note that this is not necessarily a commit stored in the fork of the repo itself. If the
    /// fork is fully merged with main, the repo fork itself may be empty (to save space)
    /// and the current commit may actually be returned from `.main`.
    func content(of fork: Fork) throws -> CommitContent<ResourceType> {
        try serialize {
            if let forkVersion = try repository.mostRecentVersion(storedIn: fork) {
                return try repository.content(of: fork, at: forkVersion)
            } else {
                let mainVersion = try repository.mostRecentVersion(storedIn: .main)!
                return try repository.content(of: .main, at: mainVersion)
            }
        }
    }
    
    /// Will return the resource, if there is one available, and `nil` otherwise.
    func resource(of fork: Fork) throws -> ResourceType? {
        try serialize {
            let content = try content(of: fork)
            if case let .resource(resource) = content {
                return resource
            } else {
                return nil
            }
        }
    }
    
    /// Same as calling `resource(of:)`.
    func value(in fork: Fork) throws -> ResourceType? {
        try resource(of: fork)
    }
    
    /// Returns the most recent (current) commit of the `Fork`. Note that this may
    /// not actually be from the corresponding fork of the repository.
    /// In particular, if a repository fork is empty, it is considered to share the same
    /// version as the main fork, and the main fork commit will be returned.
    func mostRecentCommit(of fork: Fork) throws -> Commit<ResourceType> {
        try serialize {
            let version = try mostRecentVersion(of: fork)
            let content = try content(of: fork)
            return Commit(content: content, version: version)
        }
    }
    
    /// Returns the common ancestor commit for a given fork with the main fork.
    /// This is the point at which they diverged, ie, when they were last in agreement.
    /// It may be the same as the current commit on either fork, and can even be
    /// the same as both. For example, if the fork is fully merged into main, the
    /// forks are at the same version, and the common ancestor is the same version.
    func commonAncestor(of fork: Fork) throws -> Commit<ResourceType> {
        try serialize {
            if let forkVersion = try repository.ascendingVersions(storedIn: fork).first, fork != .main {
                let content = try repository.content(of: fork, at: forkVersion)
                return Commit(content: content, version: forkVersion)
            } else {
                let mainVersion = try repository.mostRecentVersion(storedIn: .main)!
                let content = try repository.content(of: .main, at: mainVersion)
                return Commit(content: content, version: mainVersion)
            }
        }
    }
    
    /// Whether fork has commits not yet merged into main.
    /// If there are more than one commits in the repo for this fork, the fork must have changes not in main:
    /// - Zero commits means fork is the same as main.
    /// - One commit is a common ancestor, meaning main has changes, but the fork is unchanged.
    /// - Two or more commits means the fork has changes not yet in main.
    func hasUnmergedCommitsForMain(in fork: Fork) throws -> Bool {
        try serialize {
            guard fork != .main else { return false }
            return try repository.versions(storedIn: fork).count > 1
        }
    }
    
    /// Returns whether main has commits that haven't been merged into the fork yet.
    /// The common ancestor is always stored in the fork if either the fork or main get updated.
    /// By comparing common ancestor to main version, we can see if main has been updated.
    func hasUnmergedCommitsInMain(for fork: Fork) throws -> Bool {
        try serialize {
            guard fork != .main else { return false }
            let mainVersion = try repository.ascendingVersions(storedIn: .main).last!
            guard let ancestorVersion = try repository.ascendingVersions(storedIn: fork).first else {
                // If there is nothing in the fork, it is same as main
                return false
            }
            // If main is same as the common ancestor, it has no new changes
            return mainVersion != ancestorVersion
        }
    }
    
    /// Whether the fork and main fork are at the same version or not.
    func mainVersion(differsFromVersionIn fork: Fork) throws -> Bool {
        try serialize {
            try mostRecentVersionOfMain() != mostRecentVersion(of: fork)
        }
    }
    
    func mainVersion(isSameAsVersionIn fork: Fork) throws -> Bool {
        try serialize {
            try !mainVersion(differsFromVersionIn: fork)
        }
    }
}
