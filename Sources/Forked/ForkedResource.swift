import Foundation
import Synchronization

/// This manages forks of a resource. It facilitiates nonblocking concurrent changes to a single resource, and
/// provides a systematic approach for merging changes, with support for 3-way merging.
public final class ForkedResource<RespositoryType: Repository>: @unchecked Sendable {
    public typealias ResourceType = RespositoryType.ResourceType
    
    /// The repository used to store data for the forked resource.
    /// The forked resource takes complete ownership of this. You should not
    /// use the repository from outside the ForkedResource class. Doing so
    /// may lead to threading errors or logic issues in the forked resource.
    let repository: RespositoryType
        
    /// The timestamp of the most recent resource version added on any fork
    internal var mostRecentVersion: Version
    
    private let lock: NSRecursiveLock = .init()
    
    public init(repository: RespositoryType) throws {
        self.repository = repository

        if !repository.forks.contains(.main) {
            try repository.create(.main)
            let firstCommit: Commit<ResourceType> = .init(content: .none, version: .init())
            try repository.store(firstCommit, in: .main)
        }
        
        self.mostRecentVersion = try repository.mostRecentVersion()
    }
}

internal extension ForkedResource {
        
    func serialize<ReturnType>(_ block: () throws -> ReturnType) rethrows -> ReturnType {
        lock.lock()
        defer { lock.unlock() }
        return try block()
    }
    
}
