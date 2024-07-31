import Foundation

public extension ForkedResource {
    
    @discardableResult func mergeIntoMain<ResolverType: Resolver>(from fromFork: Fork, resolver: ResolverType) throws -> MergeAction where ResolverType.ResourceType == ResourceType {
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
    
    @discardableResult func mergeFromMain<ResolverType: Resolver>(into toFork: Fork, resolver: ResolverType) throws -> MergeAction where ResolverType.ResourceType == ResourceType {
        try serialize {
            switch (try hasUnmergedCommitsForMain(in: toFork), try hasUnmergedCommitsInMain(for: toFork)) {
                case (true, true):
                    let mainCommit = try mostRecentCommit(of: .main)
                    let toCommit = try mostRecentCommit(of: toFork)
                    let ancestorCommit = try commonAncestor(of: toFork)
                    let content = try resolver.mergedContent(forConflicting: (mainCommit, toCommit), withCommonAncestor: ancestorCommit)
                    try update(toFork, with: content)
                    try removeRedundantCommits(in: toFork) // Make sure we only have 2 files in fork
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
