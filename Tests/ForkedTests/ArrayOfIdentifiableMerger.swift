import Testing
import Foundation
import Forked
import ForkedModel
@testable import ForkedMerge


struct Item: Identifiable, Equatable {
    let id: String
    let value: Int
}

@ForkedModel
struct MergeableItem: Identifiable, Equatable {
    var id: String = UUID().uuidString
    @Merged var value: AccumulatingInt = .init(0)
}

extension Array where Element == Int {
    var itemsArray: [Item] {
        map { .init(id: "\($0)", value: $0) }
    }
}

struct ArrayOfIdentifiableMergerSuite {
    let ancestor: [Item] = [1, 2, 3].itemsArray
    let merger = ArrayOfIdentifiableMerger<Item>()
    let mergeableMerger = ArrayOfIdentifiableMerger<MergeableItem>()

    @Test func mergeOneSidedAppend() throws {
        let updated = [1, 2, 3, 3, 4].itemsArray
        let merged = try merger.merge(updated, withSubordinate: ancestor, commonAncestor: ancestor)
        #expect(merged.map({ $0.value }) == [1, 2, 3, 4])
    }
    
    @Test func mergeOneSidedRemove() throws {
        let updated = [1, 3].itemsArray
        let merged = try merger.merge(updated, withSubordinate: ancestor, commonAncestor: ancestor)
        #expect(merged.map({ $0.value }) == [1, 3])
    }
    
    @Test func mergeOneSidedAddAndRemove() throws {
        let updated = [1, 3, 4].itemsArray
        let merged = try merger.merge(updated, withSubordinate: ancestor, commonAncestor: ancestor)
        #expect(merged.map({ $0.value }) == [1, 3, 4])
    }
    
    @Test func mergeTwoSidedInsert() throws {
        let updated1 = [1, 2, 4, 3].itemsArray
        let updated2 = [1, 2, 4, 3, 5].itemsArray
        let merged = try merger.merge(updated2, withSubordinate: updated1, commonAncestor: ancestor)
        #expect(merged.map({ $0.value }) == [1, 2, 4, 3, 5])
    }
    
    @Test func mergeTwoSidedDeletes() throws {
        let updated1 = [1, 2, 1].itemsArray
        let updated2 = [1, 3, 1].itemsArray
        let merged = try merger.merge(updated2, withSubordinate: updated1, commonAncestor: ancestor)
        #expect(merged.map({ $0.value }) == [1])
    }
    
    @Test func mergeTwoSidedInsertAndDelete() throws {
        let updated1 = [1, 2, 4].itemsArray
        let updated2 = [1, 5, 3].itemsArray
        let merged = try merger.merge(updated2, withSubordinate: updated1, commonAncestor: ancestor)
        #expect(merged.map({ $0.value }) == [1, 5, 4])
    }
    
    @Test func mergeMergeableMultipleChanges() throws {
        let ancestor = [MergeableItem(id: "a", value: .init(1))]
        var updated1 = ancestor
        var updated2 = ancestor
        updated1.append(MergeableItem(id: "b", value: .init(2))) // [1, 2]
        updated2.append(MergeableItem(id: "c", value: .init(3)))
        updated1[0].value.value = 4 // [4, 2]
        updated2[0].value.value = 5 // [5, 3]
        updated2[1].value.value = 7 // [5, 7]
        
        let merged = try mergeableMerger.merge(updated2, withSubordinate: updated1, commonAncestor: ancestor) // [8, 7, 2]
        #expect(merged.count == 3)
        #expect(merged[0].value.value == 8)
        #expect(merged[1].value.value == 7)
        #expect(merged[2].value.value == 2)
    }
}
