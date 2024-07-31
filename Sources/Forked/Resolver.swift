import Foundation

/// Conforming types are capable of resolving conflicts during a merge.
public protocol Resolver {
    associatedtype ResourceType: Resource
    func mergedContent(forConflicting commits: (Commit<ResourceType>, Commit<ResourceType>), withCommonAncestor ancestorCommit: Commit<ResourceType>) throws -> CommitContent<ResourceType>
}
