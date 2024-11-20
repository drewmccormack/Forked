import Foundation

/// Merges an array by treating the contained elements as values.
public struct ValueArrayMerger<Element: Equatable>: Merger {
    
    public init() {}

    public func merge(_ value: [Element], withOlderConflicting other: [Element], commonAncestor: [Element]?) throws -> [Element] {
        guard let commonAncestor else { return value }
        var v1: ValueArray<Element> = .init(commonAncestor)
        var v2 = v1
        
        for diff in value.difference(from: commonAncestor) {
            switch diff {
            case let .insert(offset, element, _):
                v1.insert(element, at: offset)
            case let .remove(offset, _, _):
                v1.remove(at: offset)
            }
        }
        
        for diff in other.difference(from: commonAncestor) {
            switch diff {
            case let .insert(offset, element, _):
                v2.insert(element, at: offset)
            case let .remove(offset, _, _):
                v2.remove(at: offset)
            }
        }

        return v1.merged(with: v2).values
    }
    
}
