import Foundation

public struct ConflictingCommits<Resource> {
    public var dominant: Commit<Resource>
    public var subordinate: Commit<Resource>
    
    public init(commits: (Commit<Resource>, Commit<Resource>)) {
        if commits.0.version > commits.1.version {
            dominant = commits.0
            subordinate = commits.1
        } else {
            dominant = commits.1
            subordinate = commits.0
        }
    }
}

public struct Resolver<Resource> {
    
    public init() {}
    
    /// If the Resource is not Mergeable, fallback to last-write-wins approach. Most recent commit is chosen.
    /// Commits are ordered from newest to oldest
    public func mergedContent(forConflicting commits: ConflictingCommits<Resource>, withCommonAncestor ancestorCommit: Commit<Resource>) throws -> CommitContent<Resource> {
        return commits.dominant.content
    }
    
    /// For `Mergeable` types, we ask the resource to do the merging itself
    /// Commits are ordered from newest to oldest
    public func mergedContent(forConflicting commits: ConflictingCommits<Resource>, withCommonAncestor ancestorCommit: Commit<Resource>) throws -> CommitContent<Resource> where Resource: Mergeable {
        switch (commits.dominant.content, commits.subordinate.content, ancestorCommit.content) {
        case (.none, .none, _):
            return .none
        case (.resource, .none, _), (.resource, .resource, .none):
            return commits.dominant.content
        case (.none, .resource, _):
            return commits.subordinate.content
        case (.resource(let r1), .resource(let r2), .resource(let ra)):
            let resource = try r1.merged(withSubordinate: r2, commonAncestor: ra)
            return .resource(resource)
        }
    }
    
}
