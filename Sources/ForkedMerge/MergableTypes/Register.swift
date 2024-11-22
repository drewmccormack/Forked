import Foundation
import Forked

/// Implements Last-Writer-Wins Register. Whenever the contained value is updated, it stores a timestamp with it.
/// This allows the type to automatically merge simply by choosing the value that was written later.
/// Because there is a chance of timestamp collisions, a UUID is included to make collisions extremely unlikely.
/// Based on Convergent and commutative replicated data types by M Shapiro, N Preguiça, C Baquero, M Zawirski - 2011 - hal.inria.fr
public struct Register<T> {
    
    fileprivate struct Entry: Identifiable {
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

extension Register: ConflictFreeMergable {
    
    public func merged(with other: Self) throws -> Self {
        entry.isOrdered(after: other.entry) ? self : other
    }
    
}

extension Register: Codable where T: Codable {}
extension Register.Entry: Codable where T: Codable {}

extension Register: Equatable where T: Equatable {}
extension Register.Entry: Equatable where T: Equatable {}

extension Register: Hashable where T: Hashable {}
extension Register.Entry: Hashable where T: Hashable {}
