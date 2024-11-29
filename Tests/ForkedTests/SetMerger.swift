import Testing
@testable import ForkedMerge

struct SetMergerSuite {
    
    let merger = SetMerger<Int>()

    @Test func basicMerge() throws {
        let set1: Set<Int> = [1,2]
        let set2: Set<Int> = [1,2,4]
        let ancestor: Set<Int> = [1,2,3]
        let result = try merger.merge(set1, withOlderConflicting: set2, commonAncestor: ancestor)
        #expect(result == Set<Int>([1,2,4]))
    }
    
    @Test func noAncestor() throws {
        let set1: Set<Int> = [1,2]
        let set2: Set<Int> = [1,2,4]
        let result1 = try merger.merge(set1, withOlderConflicting: set2, commonAncestor: nil)
        #expect(result1 == set1)
        let result2 = try merger.merge(set2, withOlderConflicting: set1, commonAncestor: nil)
        #expect(result2 == set2)
    }
    
}
