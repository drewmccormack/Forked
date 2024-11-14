import Foundation

/// Merges an array by treating the contained elements as values.
struct ValueArrayMerger<T>: Merger {
    
    func merge(_ value: [T], withOlderConflicting other: [T], commonAncestor: [T]?) throws -> [T] {
        return value
    }
    
}
