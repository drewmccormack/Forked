import Foundation

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
    
//    /// This reads the repo, determining the most recent commit for the fork.
//    /// Note that this is not necessarily a commit stored in the fork itself. If the
//    /// fork is fully merged with main, the fork itself may be empty in the repo
//    /// and the current commit may actually be located in the main fork.
//    func mostRecentCommit(for fork: Fork) throws -> CommitContent<ValueType> {
////        try accessRepositoryExclusively {
////
////        }
//    }
//    
//    func content(for fork: Fork) throws -> CommitContent<ValueType> {
////        try accessRepositoryExclusively {
////        }
//    }
    
    func create(_ fork: Fork) throws {
        try accessRepositoryExclusively {
            guard !repository.forks.contains(fork) else {
                throw Error.attemptToCreateExistingFork(fork)
            }
            try repository.create(fork)
        }
    }
    
}
