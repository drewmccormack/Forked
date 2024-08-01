import Foundation

public enum CommitContent<R: Resource> {
    case none
    case resource(R)
}

public struct Commit<R: Resource>: Hashable, Equatable {
    public var content: CommitContent<R>
    public var version: Version
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(version)
    }
    
    public static func == (lhs: Commit<R>, rhs: Commit<R>) -> Bool {
        lhs.version == rhs.version
    }
}

extension CommitContent: Codable where R: Codable {}
extension Commit: Codable where R: Codable {}

extension CommitContent: Equatable where R: Equatable {}
