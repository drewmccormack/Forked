import Foundation

/// Used to chronologically order file versions. It is a standard lamport count.
public struct Version: Comparable, Hashable, Sendable, Codable {
    public var count: UInt64 = 0
    public var timestamp: Date = .now
    public var id: UUID = UUID()
    
    /// Big bang version of every ForkedResource. Effectively, it is ancient history.
    /// Also used as the initial value of any newly created branch
    public static let initialVersion: Version =
        .init(count: 0, timestamp: .distantPast, id: UUID(uuidString: "05117E83-F642-4F60-9653-95A2D4337BB5")!)
    
    /// Increase the timestamp by 1
    public func next() -> Version {
        .init(count: count+1, timestamp: .now, id: UUID())
    }
    
    public static func < (lhs: Version, rhs: Version) -> Bool {
        (lhs.count, lhs.timestamp, lhs.id.uuidString) < (rhs.count, rhs.timestamp, rhs.id.uuidString)
    }
}
