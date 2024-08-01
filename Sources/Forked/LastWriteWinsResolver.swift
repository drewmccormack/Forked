import Foundation

/// The most basic resolver. It ignores the common ancestor completely, and just picks
/// the most recent update from either branch. This is the default if you don't pass in a
/// resolver.
public struct LastWriteWinsResolver: Resolver {
    
    public init() {}
    
    public func mergedContent<R: Resource>(forConflicting commits: (Commit<R>, Commit<R>), withCommonAncestor ancestorCommit: Commit<R>) throws -> CommitContent<R> {
        let firstCommitIsMostRecent = (commits.0.version.timestamp, commits.0.version.id.uuidString) > (commits.1.version.timestamp, commits.1.version.id.uuidString)
        return firstCommitIsMostRecent ? commits.0.content : commits.1.content
    }
    
}
