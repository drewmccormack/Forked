import Foundation
import Forked

/// Implements Last-Writer-Wins Register. Whenever the contained value is updated, it stores a timestamp with it.
/// This allows the type to automatically merge simply by choosing the value that was written later.
/// Because there is a chance of timestamp collisions, a UUID is included to make collisions extremely unlikely.
/// Based on Convergent and commutative replicated data types by M Shapiro, N Preguiça, C Baquero, M Zawirski - 2011 - hal.inria.fr
public struct MergeableValue<T: Equatable>: Equatable {
    
    fileprivate struct Entry: Identifiable, Equatable {
        var value: T
        var timestamp: TimeInterval
        var id: UUID
        
        init(value: T, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate, id: UUID = UUID()) {
            self.value = value
            self.timestamp = timestamp
            self.id = id
        }
        
        func isOrdered(after other: Entry) -> Bool {
            (timestamp, id.uuidString) > (other.timestamp, other.id.uuidString)
        }
    }
    
    private var entry: Entry
    
    public var value: T {
        get {
            entry.value
        }
        set {
            entry = Entry(value: newValue)
        }
    }
    
    public init(_ value: T) {
        entry = Entry(value: value)
    }
    
}

extension MergeableValue: Mergeable {
    
    public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
        entry.isOrdered(after: other.entry) ? self : other
    }
    
}

extension MergeableValue: Codable where T: Codable {}
extension MergeableValue.Entry: Codable where T: Codable {}

extension MergeableValue: Hashable where T: Hashable {}
extension MergeableValue.Entry: Hashable where T: Hashable {}

extension MergeableValue.Entry: Sendable where T: Sendable {}
extension MergeableValue: Sendable where T: Sendable {}

extension MergeableValue: Identifiable where T: Identifiable {
    public var id: T.ID { value.id }
}
