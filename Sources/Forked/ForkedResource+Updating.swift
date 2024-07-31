import Foundation

/// Thread-safe wrappers around repository methods
public extension ForkedResource {
    
    func create(_ fork: Fork) throws {
        try serialize {
            guard !repository.forks.contains(fork) else {
                throw Error.attemptToCreateExistingFork(fork)
            }
            try repository.create(fork)
        }
    }
    
    func delete(_ fork: Fork) throws {
        try serialize {
            guard fork != .main else { throw Error.attemptToDeleteMainFork }
            try repository.delete(fork)
        }
    }
    
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
    /// Removes any commits that no longer play a role
    /// Main should only ever have one commit in it - no common ancestor.
    /// Other branches hold the common ancestors, so they will have zero (ie same as main),
    /// or two or more commits (ie common ancestor, most recent, and — temporarily — inbetweens)
    func removeRedundantCommits(in fork: Fork) throws {
        try serialize {
            let versions = try repository.ascendingVersions(storedIn: fork)
            let versionsToRemove = fork == .main ? versions.dropLast() : versions.dropFirst().dropLast()
            try versionsToRemove.forEach {
                try repository.removeCommit(at: $0, from: fork)
            }
        }
    }
    
    /// The current commit on main is copied to any empty forks in the repo, to form a common ancestor
    /// This should be called anytime main is about to be updated
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
            guard fork != .main else { throw Error.attemptToDeleteMainFork }
            let versions = try repository.ascendingVersions(storedIn: fork)
            let versionsToRemove = fork == .main ? versions.dropLast() : versions.dropFirst().dropLast()
            try versionsToRemove.forEach {
                try repository.removeCommit(at: $0, from: fork)
            }
        }
    }
    
    func removeAllCommitsExceptMostRecent(in fork: Fork) throws {
        try serialize {
            let versions = try repository.ascendingVersions(storedIn: fork)
            let versionsToRemove = versions.dropLast()
            try versionsToRemove.forEach {
                try repository.removeCommit(at: $0, from: fork)
            }
        }
    }
    
    func removeCommonAncestor(in fork: Fork) throws {
        try serialize {
            guard fork != .main else { return }
            let versions = try repository.ascendingVersions(storedIn: fork)
            try versions.first.flatMap { try repository.removeCommit(at: $0, from: fork) }
        }
    }
}
