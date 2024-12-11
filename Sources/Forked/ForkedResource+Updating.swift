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
    
}
    
public extension ForkedResource {

    /// Update the contents of a fork with a new resource value. Will create a commit, and return the `Version`.
    @discardableResult func update(_ fork: Fork, with resource: ResourceType) throws -> Version {
        try serialize {
            let newVersion = try update(fork, with: .resource(resource))
            let change = ForkChange(fork: fork, version: newVersion, mergingFork: nil)
            addToChangeStreams(change)
            return newVersion
        }
    }
    
    /// Update the contents of a fork with a new resource value. Will create a commit, and return the `Version`.
    /// The difference between a restart and an update, is that the resource passed is assumed to be the common
    /// ancestor of the fork with .main. Sometimes you can't achieve something through merging, and this gives
    /// an override. In general, it should not be needed much, but is handy when in some instances.
    /// Only use this if you know that the value of the resource precedes the value in .main, such that it
    /// is eligble to be a common ancestor. If the value in .main is actually older, doing this will undo any changes in .main.
    /// You can't restart the .main fork.
    @discardableResult func restart(_ fork: Fork, with resource: ResourceType) throws -> Version {
        guard fork != .main else { throw Error.attemptToRestartMainFork }
        return try serialize {
            let newVersion = try update(fork, with: .resource(resource))
            try removeAllCommitsExceptMostRecent(in: fork)
            let change = ForkChange(fork: fork, version: newVersion, mergingFork: nil)
            addToChangeStreams(change)
            return newVersion
        }
    }
    
    /// Adds a new commit with content `.none`. This is like setting the content to `nil`.
    /// Note that this does not remove the fork, and the fork does still have commits. However, the value of the
    /// most recent commit will be `.none`, to indicate the absence of a resource.
    /// (This construction is sometimes referred to as a "tombstone". It is a commit that indicates
    /// that something has been removed.)
    @discardableResult func removeContent(from fork: Fork) throws -> Version {
        try serialize {
            let newVersion = try update(fork, with: .none)
            let change = ForkChange(fork: fork, version: newVersion, mergingFork: nil)
            addToChangeStreams(change)
            return newVersion
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
    
}

internal extension ForkedResource {

    /// Update the contents of a fork with a new resource value, or `.none` to indicate removal of a resource.
    /// Will create a commit, and return the `Version`.
    @discardableResult func update(_ fork: Fork, with content: CommitContent<ResourceType>) throws -> Version {
        try serialize {
            // If updating main, ensure all forks have proper common ancestors
            if fork == .main {
                try addCommonAncestorsToEmptyForks()
            }
            
            // Create and store the new commit
            let newVersion = mostRecentVersion.next()
            let newCommit = Commit(content: content, version: newVersion)
            
            switch try repository.occupation(of: fork) {
            case .sameAsMain:
                // Fork is same as main, need to add common ancestor first if not main
                if fork != .main {
                    let mainCommit = try mostRecentCommit(of: .main)
                    try repository.store(mainCommit, in: fork)
                }
                try repository.store(newCommit, in: fork)
                
            case .leftBehindByMain, .aheadOrConflictingWithMain:
                // Fork already has commits, just add the new one
                try repository.store(newCommit, in: fork)
            }
            
            // Clean up any redundant commits
            try repository.removeRedundantCommits(from: fork)
            mostRecentVersion = newVersion
            
            return newVersion
        }
    }

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
            if case .sameAsMain = try repository.occupation(of: fork) {
                try repository.copyMostRecentCommit(from: .main, to: fork)
            }
        }
    }
    
    /// This can be called on any fork except main. It effectively indicates the fork is completely
    /// merged into main, and that they are at the same version.
    func removeAllCommits(in fork: Fork) throws {
        try serialize {
            guard fork != .main else { throw Error.attemptToDeleteAllDataFromMainFork }
            let versions = try repository.versions(storedIn: fork)
            try versions.forEach { try repository.removeCommit(at: $0, from: fork) }
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
