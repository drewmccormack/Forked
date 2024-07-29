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


