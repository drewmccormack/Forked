import Foundation

/// A  type representing a named fork.
public struct Fork: Hashable, Codable, Sendable {
    /// The name of the fork
    public let name: String
    
    /// Whether the fork is protected from deletion. Only
    /// the main fork has this protection for now.
    public var isProtected: Bool { self == .main }

    /// Initialize a fork with a given unique name.
    public init(name: String) {
        self.name = name
    }
    
    /// The only fork created by default. All other forkes
    /// can be merged with the main, but not directly with
    /// each other.. It acts as the central hub of the
    /// wheel of forks.
    public static let main = Fork(name: "main")
}


