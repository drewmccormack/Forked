import Foundation
import Synchronization

/// The main class. This manages forks of a resource. It facilitiates lockless concurrent changes to a single resource, and
/// provides a systematic approach for merging changes, with support for 3-way merging.
public final class ForkedResource<RespositoryType: Repository> {
    public typealias ValueType = RespositoryType.ResourceValueType
    
    public let repository: RespositoryType
    
    private let lock = NSLock()
        
    /// The timestamp of the most recent resource version added on any fork
    internal var version: Version = .init()
    
    public init(repository: RespositoryType) throws {
        self.repository = repository

        if !repository.has(.main) {
            try repository.create(.main)
            let firstCommit: Commit<ValueType> = .init(content: .none, version: .init())
            try repository.store(firstCommit, in: .main)
        }
        
        self.version = try repository.mostRecentVersion()
    }
}

internal extension ForkedResource {
        
    func accessRepositoryExclusively<ReturnType>(_ block: () throws -> ReturnType) rethrows -> ReturnType {
        lock.lock()
        defer { lock.unlock() }
        return try block()
    }
    
}
