import Testing
import Foundation
import Forked
@testable import ForkedMerge

struct ValueArrayMergerSuite {
    let ancestor = [1, 2, 3]
    let merger = ValueArrayMerger<Int>()
    
    @Test func testMergeOneSidedAppend() throws {
        let updated = [1, 2, 3, 4]
        let merged = try merger.merge(updated, withOlderConflicting: ancestor, commonAncestor: ancestor)
        #expect(merged == [1, 2, 3, 4])
    }
    
    @Test func testMergeOneSidedRemove() throws {
        let updated = [1, 3]
        let merged = try merger.merge(updated, withOlderConflicting: ancestor, commonAncestor: ancestor)
        #expect(merged == [1, 3])
    }
    
    @Test func testMergeOneSidedAddAndRemove() throws {
        let updated = [1, 3, 4]
        let merged = try merger.merge(updated, withOlderConflicting: ancestor, commonAncestor: ancestor)
        #expect(merged == [1, 3, 4])
    }
    
    @Test func testMergeTwoSidedInsert() throws {
        let updated1 = [1, 2, 4, 3]
        let updated2 = [1, 2, 3, 5]
        let merged = try merger.merge(updated2, withOlderConflicting: updated1, commonAncestor: ancestor)
        #expect(merged == [1, 2, 4, 3, 5])
    }
    
    @Test func testMergeTwoSidedDeletes() throws {
        let updated1 = [1, 2]
        let updated2 = [1, 3]
        let merged = try merger.merge(updated2, withOlderConflicting: updated1, commonAncestor: ancestor)
        #expect(merged == [1])
    }
    
    @Test func testMergeTwoSidedInsertAndDelete() throws {
        let updated1 = [1, 2, 4]
        let updated2 = [1, 5, 3]
        let merged = try merger.merge(updated2, withOlderConflicting: updated1, commonAncestor: ancestor)
        #expect(merged == [1, 5, 4])
    }
}
