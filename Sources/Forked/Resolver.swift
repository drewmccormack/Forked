import Foundation

/// Conforming types are capable of resolving conflicts during a merge.
/// You can use an existing `Resolver` or make your own to do a
/// custom merge of your resource.
public protocol Resolver {
    
    /// Merges the conflicting commits and returns a new commit for the result.
    /// The common ancestor holds the resource value when the two forks last
    /// contained the same version.
    func mergedContent<Resource>(forConflicting commits: (Commit<Resource>, Commit<Resource>), withCommonAncestor ancestorCommit: Commit<Resource>) throws -> CommitContent<Resource>
    
}
