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
            let newVersion = mostRecentVersion.next()
            let commit: Commit<ResourceType> = .init(content: content, version: newVersion)
            try repository.store(commit, in: fork)
            mostRecentVersion = newVersion
            return newVersion
        }
    }
    
}
