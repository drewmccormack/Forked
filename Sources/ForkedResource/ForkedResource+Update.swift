import Foundation

/// Thread-safe wrappers around repository methods
public extension ForkedResource {
    
    func delete(_ fork: Fork) throws {
        try accessRepositoryExclusively {
            try accessRepositoryExclusively {
                try repository.delete(fork)
            }
        }
    }
    
    @discardableResult func update(_ fork: Fork, with content: CommitContent<ValueType>) throws -> Version {
        try accessRepositoryExclusively {
            version = version.next()
            let commit: Commit<ValueType> = .init(content: content, version: version)
            try repository.store(commit, in: fork)
            return version
        }
    }
    
}
