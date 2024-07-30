import Foundation

public extension ForkedResource {
    
    func has(_ fork: Fork) -> Bool {
        serialize {
            repository.forks.contains(fork)
        }
    }
    
    var forks: [Fork] {
        serialize {
            repository.forks
        }
    }
    
    /// If you want to perform a series of calls as a transaction,
    /// preventing other threads from changing anything between calls,
    /// use this to group the transaction of calls. Note that reentrance of this
    /// method from the same thread will lead to deadlock.
    func performAtomically(_ block: () throws -> Void) throws {
        try serialize {
            try block()
        }
    }
    
    func mostRecentVersion(of fork: Fork) throws -> Version {
        try serialize {
            guard has(fork) else { throw Error.attemptToAccessNonExistentFork(fork) }
            return
                try repository.mostRecentVersion(storedIn: fork) ??
                repository.mostRecentVersion(storedIn: .main)!
        }
    }
    
    func mostRecentVersionOfMain() throws -> Version {
        try mostRecentVersion(of: .main)
    }
    
    /// This reads the repo, determining the most recent commit associated with the fork.
    /// Note that this is not necessarily a commit stored in the fork of the repo itself. If the
    /// fork is fully merged with main, the repo fork itself may be empty (to save space)
    /// and the current commit may actually be located in  main.
    func content(of fork: Fork) throws -> CommitContent<ResourceType> {
        try serialize {
            if let forkVersion = try repository.mostRecentVersion(storedIn: fork) {
                return try repository.content(of: fork, at: forkVersion)
            } else {
                let mainVersion = try repository.mostRecentVersion(storedIn: .main)!
                return try repository.content(of: .main, at: mainVersion)
            }
        }
    }
    
    /// Whether fork has commits not yet merged into main.
    /// If there are more than one commits in the repo for this fork, the fork must have changes not in main:
    /// Zero commits means fork is same as main.
    /// One commit is a common ancestor, meaning main has changes, but fork is unchanged from last merge.
    /// Two or more commits means fork has changes not yet in main.
    func unmergedCommitsForMain(existIn fork: Fork) throws -> Bool {
        try serialize {
            guard fork != .main else { return false }
            return try repository.versions(storedIn: fork).count > 1
        }
    }
    
    /// Returns whether main has commits that haven't been merged into fork yet.
    /// Common ancestor is stored in the fork if either the fork or main get updated.
    /// By comparing common ancestor to main version, we can see if main has been updated.
    func unmergedCommitsExistInMain(for fork: Fork) throws -> Bool {
        try serialize {
            let mainVersion = try repository.ascendingVersions(storedIn: .main).last!
            guard let ancestorVersion = try repository.ascendingVersions(storedIn: fork).first else {
                // If there is nothing in the fork, it is same as main
                return false
            }
            // If main is same as the common ancestor, it has no new changes
            return mainVersion != ancestorVersion
        }
    }
    
    /// Whether fork and main are at the same version
    func mainVersion(differsFromVersionIn fork: Fork) throws -> Bool {
        try serialize {
            try mostRecentVersionOfMain() != mostRecentVersion(of: fork)
        }
    }
    
}
