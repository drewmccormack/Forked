import Foundation

/// Used to chronologically order file versions
public struct LamportTimestamp: Comparable, Hashable, Sendable {
    public var count: UInt64 = 0
    public var id: UUID = UUID()
    
    /// Increase the timestamp by 1
    public mutating func tick() {
        count += 1
        id = UUID()
    }
    
    public static func < (lhs: LamportTimestamp, rhs: LamportTimestamp) -> Bool {
        (lhs.count, lhs.id.uuidString) < (rhs.count, rhs.id.uuidString)
    }
}
