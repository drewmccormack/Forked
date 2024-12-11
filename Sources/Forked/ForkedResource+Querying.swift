import Foundation

public extension ForkedResource {
    
    /// Whether a fork exists in the `ForkedResource`
    func has(_ fork: Fork) -> Bool {
        serialize {
            repository.forks.contains(fork)
        }
    }
    
    /// All forks in the resource, including the main fork, in no particular order
    var forks: [Fork] {
        serialize {
            repository.forks
        }
    }
    
    /// Returns the most recent (current) version of the `Fork`.
    func mostRecentVersion(of fork: Fork) throws -> Version {
        try mostRecentCommit(of: fork).version
    }
    
    /// The most recent (current) version of the main fork.
    func mostRecentVersionOfMain() throws -> Version {
        try mostRecentVersion(of: .main)
    }
    
    /// Returns the current content of the fork
    func content(of fork: Fork) throws -> CommitContent<ResourceType> {
        try mostRecentCommit(of: fork).content
    }
    
    /// Will return the resource, if there is one available, and `nil` otherwise.
    func resource(of fork: Fork) throws -> ResourceType? {
        try content(of: fork).resource
    }
    
    /// Same as calling `resource(of:)`.
    func value(in fork: Fork) throws -> ResourceType? {
        try resource(of: fork)
    }
    
    /// Returns the most recent (current) commit of the `Fork`.
    func mostRecentCommit(of fork: Fork) throws -> Commit<ResourceType> {
        try serialize {
            switch try repository.occupation(of: fork) {
            case .sameAsMain:
                let mainVersion = try repository.mostRecentVersion(storedIn: .main)!
                let content = try repository.content(of: .main, at: mainVersion)
                return Commit(content: content, version: mainVersion)
            case .leftBehindByMain(let commit), .aheadOrConflictingWithMain(let commit, _):
                return commit
            }
        }
    }
    
    /// Returns the common ancestor commit for a given fork with the main fork.
    func commonAncestor(of fork: Fork) throws -> Commit<ResourceType> {
        try serialize {
            switch try repository.occupation(of: fork) {
            case .sameAsMain:
                return try mostRecentCommit(of: .main)
            case .leftBehindByMain(let commit):
                return commit
            case .aheadOrConflictingWithMain(_, commonAncestor: let ancestor):
                return ancestor
            }
        }
    }
    
    /// Whether fork has commits not yet merged into main.
    func hasUnmergedCommitsForMain(in fork: Fork) throws -> Bool {
        try serialize {
            guard fork != .main else { return false }
            
            switch try repository.occupation(of: fork) {
            case .sameAsMain, .leftBehindByMain:
                return false
            case .aheadOrConflictingWithMain(let commit, commonAncestor: let ancestor):
                return commit.version != ancestor.version
            }
        }
    }
    
    /// Returns whether main has commits that haven't been merged into the fork yet.
    func hasUnmergedCommitsInMain(for fork: Fork) throws -> Bool {
        try serialize {
            guard fork != .main else { return false }
            
            let mainVersion = try repository.mostRecentVersion(storedIn: .main)!
            
            switch try repository.occupation(of: fork) {
            case .sameAsMain:
                return false
            case .leftBehindByMain(let commit):
                return mainVersion != commit.version
            case .aheadOrConflictingWithMain(_, commonAncestor: let ancestor):
                return mainVersion != ancestor.version
            }
        }
    }
    
    /// Whether the fork and main fork are at the same version or not.
    func mainVersion(differsFromVersionIn fork: Fork) throws -> Bool {
        try serialize {
            try mostRecentVersionOfMain() != mostRecentVersion(of: fork)
        }
    }
    
    func mainVersion(isSameAsVersionIn fork: Fork) throws -> Bool {
        try !mainVersion(differsFromVersionIn: fork)
    }
    
    /// If you want to perform a series of calls as a single transaction,
    /// preventing other threads from changing anything between calls,
    /// use this to group the transaction of calls. Note that reentrance of this
    /// method from the same thread will lead to deadlock. It is best not to
    /// execute long running code in the block, because all other interactions
    /// with the `ForkedResource` will block waiting.
    func performAtomically<ReturnType>(_ block: () throws -> ReturnType) rethrows -> ReturnType {
        try serialize {
            try block()
        }
    }
}
