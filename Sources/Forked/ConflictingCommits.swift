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
