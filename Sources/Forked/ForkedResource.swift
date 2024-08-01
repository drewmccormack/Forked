import Foundation
import Synchronization

/// This manages forks of a resource. It facilitiates concurrent changes to a single resource, and
/// provides a systematic approach for merging changes, with support for 3-way merging.
public final class ForkedResource<RespositoryType: Repository>: @unchecked Sendable {
    public typealias ResourceType = RespositoryType.ResourceType
    
    /// The repository used to store data for the forked resource.
    /// The forked resource takes complete ownership of this. You should not
    /// use the repository from outside the `ForkedResource` object. Doing so
    /// may lead to threading errors or logic bugs.
    let repository: RespositoryType
        
    /// The timestamp of the most recent resource version added on any fork
    internal var mostRecentVersion: Version
    
    private let lock: NSRecursiveLock = .init()
    
    /// Initialize the `ForkedResource` with a repository. If the repository is new,
    /// and has no main fork, one will be added with an initial commit.
    public init(repository: RespositoryType) throws {
        self.repository = repository

        if !repository.forks.contains(.main) {
            try repository.create(.main, withInitialCommit: .init(content: .none, version: Version.initialVersion))
        }
        
        self.mostRecentVersion = try repository.mostRecentVersion()
    }
}

internal extension ForkedResource {
        
    /// Used to serialize access to the data of the `ForkedResource` across threads.
    func serialize<ReturnType>(_ block: () throws -> ReturnType) rethrows -> ReturnType {
        lock.lock()
        defer { lock.unlock() }
        return try block()
    }
    
}
