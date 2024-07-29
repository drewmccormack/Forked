import Foundation

public enum CommitContent<R: Resource> {
    case none
    case resourceValue(R)
}

public struct Commit<R: Resource> {
    public var content: CommitContent<R>
    public var version: Version
}

extension CommitContent: Codable where R: Codable {}
extension Commit: Codable where R: Codable {}
