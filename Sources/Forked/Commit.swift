import Foundation

/// A wrapper to hold the resource. This allows for the resource to be
/// absent in a fork, similar to using `nil`.
public enum CommitContent<Resource: Equatable> {
    /// The content is not present. Perhaps it has not been added yet,
    /// or it may have been removed.
    case none
    
    /// The content contains a value of the resource.
    case resource(Resource)
        
    public var resource: Resource? {
        if case let .resource(resource) = self {
            return resource
        }
        return nil
    }
}

extension CommitContent: Codable where Resource: Codable {}
extension CommitContent: Equatable {
    
    /// The resource is Equatable, so test explicitly for equality.
    public static func == (lhs: CommitContent<Resource>, rhs: CommitContent<Resource>) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case let (.resource(lhsResource), .resource(rhsResource)):
            return lhsResource == rhsResource
        default:
            return false
        }
    }
    
}

/// A commit comprises of content, which is usually a value of the stored resource,
/// together with a `Version`.
public struct Commit<Resource: Equatable>: Hashable, Equatable {
    /// The content stored in the commit, usually a copy of the resource.
    public var content: CommitContent<Resource>
    
    /// The version when the copy of the resource was committed.
    public var version: Version
        
    public func hash(into hasher: inout Hasher) {
        hasher.combine(version)
    }
    
    public static func == (lhs: Commit<Resource>, rhs: Commit<Resource>) -> Bool {
        lhs.version == rhs.version
    }
}

extension Commit: Codable where Resource: Codable {}

