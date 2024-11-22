//
//  MergingSet.swift
//  Forked
//
//  Created by Drew McCormack on 22/11/2024.
//

import Foundation
import Forked

/// Observed-Remove Set. Can add and remove like a normal set.
/// Based on Convergent and commutative replicated data types by M Shapiro, N Preguiça, C Baquero, M Zawirski - 2011 - hal.inria.fr
public struct MergableSet<T: Hashable> {
    
    fileprivate struct Metadata {
        var isDeleted: Bool
        var lamportTimestamp: LamportTimestamp
        
        init(lamportTimestamp: LamportTimestamp) {
            self.isDeleted = false
            self.lamportTimestamp = lamportTimestamp
        }
    }
    
    private var metadataByValue: [T:Metadata]
    private var currentTimestamp: LamportTimestamp
    
    public var values: Set<T> {
        get {
            let values = metadataByValue.filter({ !$1.isDeleted }).map({ $0.key })
            return Set(values)
        }
        set {
            let old = self.values
            let inserted = newValue.subtracting(old)
            let deleted = old.subtracting(newValue)
            inserted.forEach { insert($0) }
            deleted.forEach { remove($0) }
        }
    }
    
    public var count: Int {
        metadataByValue.reduce(0) { result, pair in
            result + (pair.value.isDeleted ? 0 : 1)
        }
    }
        
    public init() {
        self.metadataByValue = [:]
        self.currentTimestamp = .init()
    }
    
    public init(array elements: [T]) {
        self = .init()
        elements.forEach { self.insert($0) }
    }
    
    @discardableResult public mutating func insert(_ value: T) -> Bool {
        currentTimestamp.tick()
        
        let metadata = Metadata(lamportTimestamp: currentTimestamp)
        let isNewInsert: Bool
        
        if let oldMetadata = metadataByValue[value] {
            isNewInsert = oldMetadata.isDeleted
        } else {
            isNewInsert = true
        }
        metadataByValue[value] = metadata
        
        return isNewInsert
    }
    
    @discardableResult public mutating func remove(_ value: T) -> T? {
        let returnValue: T?
    
        if let oldMetadata = metadataByValue[value], !oldMetadata.isDeleted {
            currentTimestamp.tick()
            var metadata = Metadata(lamportTimestamp: currentTimestamp)
            metadata.isDeleted = true
            metadataByValue[value] = metadata
            returnValue = value
        } else {
            returnValue = nil
        }
        
        return returnValue
    }
    
    public func contains(_ value: T) -> Bool {
        !(metadataByValue[value]?.isDeleted ?? true)
    }
}

extension MergableSet: ConflictFreeMergable {
    
    public func merged(with other: Self) throws -> Self {
        var result = self
        result.metadataByValue = other.metadataByValue.reduce(into: metadataByValue) { result, entry in
            let firstMetadata = result[entry.key]
            let secondMetadata = entry.value
            if let firstMetadata {
                result[entry.key] = firstMetadata.lamportTimestamp > secondMetadata.lamportTimestamp ? firstMetadata : secondMetadata
            } else {
                result[entry.key] = secondMetadata
            }
        }
        result.currentTimestamp = Swift.max(self.currentTimestamp, other.currentTimestamp)
        return result
    }
    
}

extension MergableSet: Codable where T: Codable {}
extension MergableSet.Metadata: Codable where T: Codable {}

extension MergableSet: Equatable where T: Equatable {}
extension MergableSet.Metadata: Equatable where T: Equatable {}

extension MergableSet: Hashable where T: Hashable {}
extension MergableSet.Metadata: Hashable where T: Hashable {}

extension MergableSet: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: T...) {
        self = .init(array: elements)
    }
}
