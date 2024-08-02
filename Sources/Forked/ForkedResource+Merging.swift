import Foundation

public extension ForkedResource {
    
    /// Merges from one fork into the main fork. The resolver is used if a conflict exists, and may perform a 3-way merge.
    /// By default, if no resolver is passed in, a last-write-wins strategy is applied, namely the most recent version is chosen as the result.
    /// A `MergeAction` is returned to indicate the type of merge that took place.
    /// After this operation, the main fork may be updated. The version of the other fork will be unchanged.
    /// Note that this may change the commits stored in unrelated forks, in order to preserve common ancestors.
    @discardableResult func mergeIntoMain(from fromFork: Fork, resolver: (any Resolver) = LastWriteWinsResolver()) throws -> MergeAction {
        try serialize {
            switch (try hasUnmergedCommitsForMain(in: fromFork), try hasUnmergedCommitsInMain(for: fromFork)) {
                case (true, true):
                    let mainCommit = try mostRecentCommit(of: .main)
                    let fromCommit = try mostRecentCommit(of: fromFork)
                    let ancestorCommit = try commonAncestor(of: fromFork)
                    let content = try resolver.mergedContent(forConflicting: (mainCommit, fromCommit), withCommonAncestor: ancestorCommit)
                    try update(.main, with: content)
                    try removeAllCommitsExceptMostRecent(in: fromFork) // Fork version is now common ancestor
                    return .resolveConflict
                case (true, false):
                    try addCommonAncestorsToEmptyForks()
                    try repository.copyMostRecentCommit(from: fromFork, to: .main)
                    try removeRedundantCommits(in: .main)
                    try removeAllCommits(in: fromFork)
                    return .fastForward
                case (false, true), (false, false):
                    return .none
            }
        }
    }
    
    /// Merges from the main fork into another fork. The resolver is used if a conflict exists, and may perform a 3-way merge.
    /// By default, if no resolver is passed in, a last-write-wins strategy is applied, namely the most recent version is chosen as the result.
    /// A `MergeAction` is returned to indicate the type of merge that took place.
    /// After this operation, the fork may be updated, with the version of the main fork unchanged.
    @discardableResult func mergeFromMain(into toFork: Fork, resolver: (any Resolver) = LastWriteWinsResolver()) throws -> MergeAction {
        try serialize {
            switch (try hasUnmergedCommitsForMain(in: toFork), try hasUnmergedCommitsInMain(for: toFork)) {
                case (true, true):
                    let mainCommit = try mostRecentCommit(of: .main)
                    let toCommit = try mostRecentCommit(of: toFork)
                    let ancestorCommit = try commonAncestor(of: toFork)
                    let content = try resolver.mergedContent(forConflicting: (mainCommit, toCommit), withCommonAncestor: ancestorCommit)
                    try update(toFork, with: content)
                    try repository.copyMostRecentCommit(from: .main, to: toFork) // New common ancestor is the main version
                    try removeCommonAncestor(in: toFork) // Remove old common ancestor
                    return .resolveConflict
                case (false, true):
                    try removeAllCommits(in: toFork)
                    return .fastForward
                case (true, false), (false, false):
                    return .none
            }
        }
    }
}

public extension ForkedResource {
    
    /// Merges other forks into main, and then main into the target fork, so it has up-to-date data from all other forks.
    /// You can pass in `.main` if you want to merge all other forks into `.main`.
    func mergeAllForks(into toFork: Fork, resolver: (any Resolver) = LastWriteWinsResolver()) throws {
        try serialize {
            for fork in forks where fork != toFork && fork != .main {
                try mergeIntoMain(from: fork, resolver: resolver)
            }
            try mergeFromMain(into: toFork, resolver: resolver)
        }
    }
    
    /// Merges all forks so they are all at the same version. This involves merging all forks into the main fork
    /// first, and then merging the main fork into all other forks.
    func mergeAllForks(resolver: (any Resolver) = LastWriteWinsResolver()) throws {
        try serialize {
            // Update main with changes in all other forks
            for fork in forks where fork != .main {
                try mergeIntoMain(from: fork, resolver: resolver)
            }
            
            // Merge back into other forks to fast-forward them to main version
            for fork in forks where fork != .main {
                let action = try mergeFromMain(into: fork, resolver: resolver)
                assert(action == .fastForward)
            }
        }
    }
    
}
