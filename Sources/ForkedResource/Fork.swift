import Foundation

/// A simple type representing a named fork of the resource.
public struct Fork: Hashable, Sendable {
    public let name: String
    public var protected: Bool { self == .main }

    public init(name: String) {
        self.name = name
    }
    
    /// The only fork created by default. All other forkes are formed from
    /// the main, and can be merged back into it. It acts as the central trunk of the
    /// version tree
    public static let main = Fork(name: "main")
}

extension ForkedResource {
    
//    /// Creates a fork, or throws if one already exists
//    public func createFork(_ fork: Fork) throws {
//        try executeOnPrivateQueue {
//            let dir = directoryURL(for: fork)
//            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
//        }
//    }
//    
//    /// Deletes a fork, or throws if no fork found (or attampt to delete main).
//    /// This will discard any changes in the fork that haven't be merged yet.
//    public func deleteFork(_ fork: Fork) throws {
//        try executeOnPrivateQueue {
//            if fork == .main { throw Error.attemptToDeleteMainFork }
//            let dir = directoryURL(for: fork)
//            if dir.resourceExists {
//                try fileManager.removeItem(at: dir)
//            }
//        }
//    }
    
}
