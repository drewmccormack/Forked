import Foundation

/// Thread-safe wrappers around repository methods
public extension ForkedResource {
    
    /// Create a new fork.Will throw if a fork with the same name already exists.
    func create(_ fork: Fork) throws {
        try serialize {
            guard !repository.forks.contains(fork) else {
                throw Error.attemptToCreateExistingFork(fork)
            }
            try repository.create(fork, withInitialCommit: .init(content: .none, version: Version.initialVersion))
        }
    }
    
    /// Delete an existing fork. If the fork does not exist, it will throw.
    func delete(_ fork: Fork) throws {
        try serialize {
            guard !fork.isProtected else { throw Error.attemptToDeleteProtectedFork(fork) }
            try repository.delete(fork)
        }
    }
    
    /// Update the contents of a fork with a new resource value. Will create a commit, and return the `Version`.
    @discardableResult func update(_ fork: Fork, with resource: ResourceType) throws -> Version {
        try serialize {
            try update(fork, with: .resource(resource))
        }
    }
    
    /// Adds a new commit with content `.none`. This is like setting the content to `nil`.
    /// Note that this does not remove the fork, and the fork does still have commits. However, the value of the
    /// most recent commit will be `.none`, to indicate the absence of a resource.
    /// (This construction is sometimes referred to as a "tombstone". It is a commit that indicates
    /// that something has been removed.)
    @discardableResult func removeContent(from fork: Fork) throws -> Version {
        try serialize {
            try update(fork, with: .none)
        }
    }
    
    /// Removes all content from all branches, resetting to the initial state.
    /// It does not remove the existing branches, but removes their content.
    func removeAllContent() throws {
        try serialize {
            try repository.forks.forEach { fork in
                try repository.delete(fork)
                try repository.create(fork, withInitialCommit: .init(content: .none, version: Version.initialVersion))
            }
        }
    }
    
    /// Update the contents of a fork with a new resource value, or `.none` to indicate removal of a resource.
    /// Will create a commit, and return the `Version`.
    @discardableResult func update(_ fork: Fork, with content: CommitContent<ResourceType>) throws -> Version {
        try serialize {
            func addNewCommit() throws {
                if fork == .main { try addCommonAncestorsToEmptyForks() }
                let newVersion = mostRecentVersion.next()
                let commit: Commit<ResourceType> = .init(content: content, version: newVersion)
                try repository.store(commit, in: fork)
                mostRecentVersion = newVersion
            }
            
            // Clean up redundant versions, and update common ancestors
            let versions = try repository.ascendingVersions(storedIn: fork)
            switch versions.count {
            case 0:
                assert(fork != .main, "main fork should never have zero commits")
                try repository.copyMostRecentCommit(from: .main, to: fork) // Copy in common ancestor
                try addNewCommit()
            case 1...:
                try addNewCommit()
                try removeRedundantCommits(in: fork)
            default:
                fatalError()
            }
            
            return mostRecentVersion
        }
    }
}

internal extension ForkedResource {
    /// Removes any commits that no longer play a role.
    /// Main should only ever have one commit in it - no common ancestor.
    /// Other branches hold the common ancestors, so they will have zero (ie same as main),
    /// one (ie a comon anacestor),
    /// or two (ie common ancestor and a recent commit).
    func removeRedundantCommits(in fork: Fork) throws {
        try serialize {
            let versions = try repository.ascendingVersions(storedIn: fork)
            let versionsToRemove = fork == .main ? versions.dropLast() : versions.dropFirst().dropLast()
            try versionsToRemove.forEach {
                try repository.removeCommit(at: $0, from: fork)
            }
        }
    }
    
    /// The current commit on main is copied to any empty forks in the repo, to form a common ancestor.
    /// This should be called anytime main is about to be updated.
    func addCommonAncestorsToEmptyForks() throws {
        for fork in forks where fork != .main {
            let versions = try repository.versions(storedIn: fork)
            if versions.isEmpty {
                try repository.copyMostRecentCommit(from: .main, to: fork)
            }
        }
    }
    
    /// This can be called on any fork except main. It effectively indicates the fork is completely
    /// merged into main, and that they are at the same version.
    func removeAllCommits(in fork: Fork) throws {
        try serialize {
            guard fork != .main else { throw Error.attemptToDeleteAllDataFromMainFork }
            let versions = try repository.ascendingVersions(storedIn: fork)
            try versions.forEach {
                try repository.removeCommit(at: $0, from: fork)
            }
        }
    }
    
    /// Deletes all commits in a fork except the most recent one.
    func removeAllCommitsExceptMostRecent(in fork: Fork) throws {
        try serialize {
            let versions = try repository.ascendingVersions(storedIn: fork)
            let versionsToRemove = versions.dropLast()
            try versionsToRemove.forEach {
                try repository.removeCommit(at: $0, from: fork)
            }
        }
    }
    
    /// Removes the common ancestor in a fork. It has no effect on the main fork,
    /// because that does not store a common ancestor.
    func removeCommonAncestor(in fork: Fork) throws {
        try serialize {
            guard fork != .main else { return }
            let versions = try repository.ascendingVersions(storedIn: fork)
            try versions.first.flatMap { try repository.removeCommit(at: $0, from: fork) }
        }
    }
}
