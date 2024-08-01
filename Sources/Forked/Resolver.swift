import Foundation

/// Conforming types are capable of resolving conflicts during a merge.
public protocol Resolver {
    func mergedContent<R: Resource>(forConflicting commits: (Commit<R>, Commit<R>), withCommonAncestor ancestorCommit: Commit<R>) throws -> CommitContent<R>
}
