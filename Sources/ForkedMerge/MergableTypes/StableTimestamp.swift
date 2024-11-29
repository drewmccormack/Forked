import Foundation

/// A orderable timestamp that should be deterministic across devices.
internal struct StableTimestamp: Codable, Identifiable, Comparable, Hashable {
    var timestamp: Date = .now
    var id: UUID = UUID()
    
    public mutating func tick() {
        self = .init()
    }
    
    static func < (lhs: StableTimestamp, rhs: StableTimestamp) -> Bool {
        (lhs.timestamp, lhs.id.uuidString) < (rhs.timestamp, rhs.id.uuidString)
    }
}
