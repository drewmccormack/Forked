import Foundation
import Synchronization

/// The main class. This manages forks of a resource. It facilitiates lockless concurrent changes to a single resource, and
/// provides a systematic approach for merging changes, with support for 3-way merging.
public final class ForkedResource<R: ResourceValue> {
    
    public let repository: Repository
    
    private let repositoryLock = NSLock()
    private var forkToLock: [Fork:NSLock] = [:]
        
    /// The timestamp of the most recent resource version added on any fork
    internal var lamportTimestamp = LamportTimestamp()
    
    public init(repository: any Repository) throws {
        self.repository = repository

        if !repository.has(.main) {
            try repository.create(.main)
            try repository.update(.main, with: ForkContent<R>.none)
        }
        
        self.lamportTimestamp = try forks.map { try repository.mostRecentTimestamp(in: $0) }.max()!
        
        forkToLock = forks.reduce(into: [:]) { partialResult, fork in
            partialResult[fork] = NSLock()
        }
    }
}

/// Thread-safe wrappers around repository methods
public extension ForkedResource {
    
    func has(_ fork: Fork) -> Bool {
        accessRepositoryExclusively {
            repository.has(fork)
        }
    }
    
    var forks: [Fork] {
        accessRepositoryExclusively {
            repository.forks
        }
    }
    
    func content(for fork: Fork) throws -> ForkContent<R> {
        try accessRepositoryExclusively(for: fork) {
            try repository.content(for: fork)
        }
    }
    
    func create(_ fork: Fork) throws {
        try accessRepositoryExclusively {
            guard !repository.forks.contains(fork) else {
                throw Error.attemptToCreateExistingFork
            }
            forkToLock[fork] = NSLock()
            try repository.create(fork)
        }
    }
    
    func delete(_ fork: Fork) throws {
        try accessRepositoryExclusively {
            try accessRepositoryExclusively(for: fork) {
                try repository.delete(fork)
                forkToLock[fork] = nil
            }
        }
    }
    
    @discardableResult func update(_ fork: Fork, with content: ForkContent<R>) throws -> LamportTimestamp {
        try accessRepositoryExclusively(for: fork) {
            try repository.update(fork, with: content)
        }
    }
    
}


internal extension ForkedResource {
        
    func accessRepositoryExclusively<ReturnType>(_ block: () throws -> ReturnType) rethrows -> ReturnType {
        repositoryLock.lock()
        defer { repositoryLock.unlock() }
        return try block()
    }
    
    func accessRepositoryExclusively<ReturnType>(for fork: Fork, _ block: () throws -> ReturnType) throws -> ReturnType {
        guard let lock = forkToLock[fork] else { throw Error.attemptToAccessNonExistentFork }
        lock.lock()
        defer { lock.unlock() }
        return try block()
    }
    
}
