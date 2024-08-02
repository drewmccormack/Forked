import Foundation

public struct ConflictingCommits<Resource> {
    public var newer: Commit<Resource>
    public var older: Commit<Resource>
    
    public init(commits: (Commit<Resource>, Commit<Resource>)) {
        if commits.0.version > commits.1.version {
            newer = commits.0
            older = commits.1
        } else {
            newer = commits.1
            older = commits.0
        }
    }
}

public struct Resolver<Resource> {
    
    public init() {}
    
    /// If the Resource is not Mergable, fallback to last-write-wins approach. Most recent commit is chosen.
    /// Commits are ordered from newest to oldest
    public func mergedContent(forConflicting commits: ConflictingCommits<Resource>, withCommonAncestor ancestorCommit: Commit<Resource>) throws -> CommitContent<Resource> {
        return commits.newer.content
    }
    
    /// For `Mergable` types, we ask the resource to do the merging itself
    /// Commits are ordered from newest to oldest
    public func mergedContent(forConflicting commits: ConflictingCommits<Resource>, withCommonAncestor ancestorCommit: Commit<Resource>) throws -> CommitContent<Resource> where Resource: Mergable {
        switch (commits.newer.content, commits.older.content) {
        case (.none, .none):
            return .none
        case (.resource, .none):
            return commits.newer.content
        case (.none, .resource):
            return commits.older.content
        case (.resource(let r1), .resource(let r2)):
            let resource = try r1.merged(withOlderConflicting: r2, commonAncestor: ancestorCommit.content.resource)
            return .resource(resource)
        }
    }
    
}
