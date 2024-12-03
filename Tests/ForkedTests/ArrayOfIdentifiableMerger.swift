import Testing
import Foundation
import Forked
@testable import ForkedMerge


struct Item: Identifiable, Equatable {
    let id: String
    let value: Int
}

extension Array where Element == Int {
    var itemsArray: [Item] {
        map { .init(id: "\($0)", value: $0) }
    }
}

struct ArrayOfIdentifiableMergerSuite {
    let ancestor: [Item] = [1, 2, 3].itemsArray
    let merger = ArrayOfIdentifiableMerger<Item>()
    
    @Test func mergeOneSidedAppend() throws {
        let updated = [1, 2, 3, 3, 4].itemsArray
        let merged = try merger.merge(updated, withOlderConflicting: ancestor, commonAncestor: ancestor)
        #expect(merged.map({ $0.value }) == [1, 2, 3, 4])
    }
    
    @Test func mergeOneSidedRemove() throws {
        let updated = [1, 3].itemsArray
        let merged = try merger.merge(updated, withOlderConflicting: ancestor, commonAncestor: ancestor)
        #expect(merged.map({ $0.value }) == [1, 3])
    }
    
    @Test func mergeOneSidedAddAndRemove() throws {
        let updated = [1, 3, 4].itemsArray
        let merged = try merger.merge(updated, withOlderConflicting: ancestor, commonAncestor: ancestor)
        #expect(merged.map({ $0.value }) == [1, 3, 4])
    }
    
    @Test func mergeTwoSidedInsert() throws {
        let updated1 = [1, 2, 4, 3].itemsArray
        let updated2 = [1, 2, 4, 3, 5].itemsArray
        let merged = try merger.merge(updated2, withOlderConflicting: updated1, commonAncestor: ancestor)
        #expect(merged.map({ $0.value }) == [1, 2, 4, 3, 5])
    }
    
    @Test func mergeTwoSidedDeletes() throws {
        let updated1 = [1, 2, 1].itemsArray
        let updated2 = [1, 3, 1].itemsArray
        let merged = try merger.merge(updated2, withOlderConflicting: updated1, commonAncestor: ancestor)
        #expect(merged.map({ $0.value }) == [1])
    }
    
    @Test func mergeTwoSidedInsertAndDelete() throws {
        let updated1 = [1, 2, 4].itemsArray
        let updated2 = [1, 5, 3].itemsArray
        let merged = try merger.merge(updated2, withOlderConflicting: updated1, commonAncestor: ancestor)
        #expect(merged.map({ $0.value }) == [1, 5, 4])
    }
}
