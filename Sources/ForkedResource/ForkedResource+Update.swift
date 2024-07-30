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

private extension ForkedResource {
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
    func addCommonAncestorsToEmptyForks() throws {
        for fork in forks where fork != .main {
            let versions = try repository.versions(storedIn: fork)
            if versions.isEmpty {
                try repository.copyMostRecentCommit(from: .main, to: fork)
            }
        }
    }
}
