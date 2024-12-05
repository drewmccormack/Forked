import Foundation
import Forked

/// Merges an array, ensuring that the result has elements with unqiue identifiers.
public struct ArrayOfIdentifiableMerger<Element: Identifiable & Equatable>: Merger {
    public init() {}
}

extension ArrayOfIdentifiableMerger where Element: Mergeable {
    
    public func merge(_ value: [Element], withSubordinate other: [Element], commonAncestor: [Element]) throws -> [Element] {
        try performMerge(value, withSubordinate: other, commonAncestor: commonAncestor, elementMerge: mergeElement)
    }
    
    private func mergeElement(_ element: Element, _ otherElement: Element, _ commonAncestor: Element) throws -> Element {
        try element.merged(withSubordinate: otherElement, commonAncestor: commonAncestor)
    }

}

extension ArrayOfIdentifiableMerger {
    
    public func merge(_ value: [Element], withSubordinate other: [Element], commonAncestor: [Element]) throws -> [Element] {
        try performMerge(value, withSubordinate: other, commonAncestor: commonAncestor, elementMerge: mergeElement)
    }
    
    private func performMerge(_ value: [Element], withSubordinate other: [Element], commonAncestor: [Element], elementMerge: (Element, Element, Element) throws -> Element) throws -> [Element] {
        let v0: MergeableArray<Element.ID> = .init(commonAncestor.map(\.id))
        var v2 = v0
        var v1 = v0
        v2.values = other.map(\.id)
        v1.values = value.map(\.id)
        let resultIds = try v1.merged(withSubordinate: v2, commonAncestor: v0).values.filterDuplicates { $0 }
        
        let idToElement: [Element.ID:Element] = .init(uniqueKeysWithValues: value.filterDuplicates(identifyingWith: { $0.id }).map { ($0.id, $0) })
        let idToOtherElement: [Element.ID:Element] = .init(uniqueKeysWithValues: other.filterDuplicates(identifyingWith: { $0.id }).map { ($0.id, $0) })
        let idToAncestorElement: [Element.ID:Element] = .init(uniqueKeysWithValues: commonAncestor.filterDuplicates(identifyingWith: { $0.id }).map { ($0.id, $0) })
        let result = try resultIds.map { id in
            switch (idToElement[id], idToOtherElement[id], idToAncestorElement[id]) {
            case let (element?, otherElement?, ancestorElement?):
                return try elementMerge(element, otherElement, ancestorElement)
            case let (element?, _, _), let (nil, element?, _):
                return element
            case (nil, nil, _):
                fatalError("Missing element with id \(id)")
            }
        }
        return result
    }
    
    private func mergeElement(_ element: Element, _ otherElement: Element, _ commonAncestor: Element) throws -> Element {
        element == commonAncestor ? otherElement : element
    }
    
}

