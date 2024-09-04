import Foundation
import Synchronization

/// This manages forks of a resource. It facilitiates concurrent changes to a single resource, and
/// provides a systematic approach for merging changes, with support for 3-way merging.
public final class ForkedResource<RespositoryType: Repository>: @unchecked Sendable {
    public typealias ResourceType = RespositoryType.Resource
    
    /// The repository used to store data for the forked resource.
    /// The forked resource takes complete ownership of this. You should not
    /// use the repository from outside the `ForkedResource` object. Doing so
    /// may lead to threading errors or logic bugs.
    let repository: RespositoryType
    
    /// Resolves conflicts
    internal let resolver: Resolver<ResourceType> = .init()
        
    /// The timestamp of the most recent resource version added on any fork
    internal var mostRecentVersion: Version
    
    private let lock: NSRecursiveLock = .init()
    
    private typealias StreamID = UInt64
    private var nextStreamID: StreamID = 0
    private var continuations: [StreamID:ChangeStream.Continuation] = [:]

    /// Initialize the `ForkedResource` with a repository. If the repository is new,
    /// and has no main fork, one will be added with an initial commit.
    public init(repository: RespositoryType) throws {
        self.repository = repository

        if !repository.forks.contains(.main) {
            try repository.create(.main, withInitialCommit: .init(content: .none, version: Version.initialVersion))
        }
        
        self.mostRecentVersion = try repository.mostRecentVersion()
    }
    
    deinit {
        for contination in continuations.values {
            contination.finish()
        }
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

extension ForkedResource {
    
    /// Creates and returns an AsyncStream which provides a
    /// stream of all changes. It fires for any change to any fork.
    public var changeStream: ChangeStream {
        serialize {
            AsyncStream { continuation in
                let id = nextStreamID
                continuations[id] = continuation
                continuation.onTermination = { @Sendable [self] _ in
                    serialize {
                        continuations[id] = nil
                    }
                }
                nextStreamID += 1
            }
        }
    }
    
    internal func addToChangeStreams(_ change: ForkChange) {
        serialize {
            for continuation in continuations.values {
                continuation.yield(change)
            }
        }
    }
    
}
