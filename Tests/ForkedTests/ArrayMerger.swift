import Testing
import Foundation
import Forked
@testable import ForkedMerge

struct ArrayMergerSuite {
    let ancestor = [1, 2, 3]
    let merger = ArrayMerger<Int>()
    
    @Test func mergeOneSidedAppend() throws {
        let updated = [1, 2, 3, 4]
        let merged = try merger.merge(updated, withSubordinate: ancestor, commonAncestor: ancestor)
        #expect(merged == [1, 2, 3, 4])
    }
    
    @Test func mergeOneSidedRemove() throws {
        let updated = [1, 3]
        let merged = try merger.merge(updated, withSubordinate: ancestor, commonAncestor: ancestor)
        #expect(merged == [1, 3])
    }
    
    @Test func mergeOneSidedAddAndRemove() throws {
        let updated = [1, 3, 4]
        let merged = try merger.merge(updated, withSubordinate: ancestor, commonAncestor: ancestor)
        #expect(merged == [1, 3, 4])
    }
    
    @Test func mergeTwoSidedInsert() throws {
        let updated1 = [1, 2, 4, 3]
        let updated2 = [1, 2, 3, 5]
        let merged = try merger.merge(updated2, withSubordinate: updated1, commonAncestor: ancestor)
        #expect(merged == [1, 2, 4, 3, 5])
    }
    
    @Test func mergeTwoSidedDeletes() throws {
        let updated1 = [1, 2]
        let updated2 = [1, 3]
        let merged = try merger.merge(updated2, withSubordinate: updated1, commonAncestor: ancestor)
        #expect(merged == [1])
    }
    
    @Test func mergeTwoSidedInsertAndDelete() throws {
        let updated1 = [1, 2, 4]
        let updated2 = [1, 5, 3]
        let merged = try merger.merge(updated2, withSubordinate: updated1, commonAncestor: ancestor)
        #expect(merged == [1, 5, 4])
    }
}
