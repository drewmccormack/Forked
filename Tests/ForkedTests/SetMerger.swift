import Testing
@testable import ForkedMerge

struct SetMergerSuite {
    
    let merger = SetMerger<Int>()

    @Test func basicMerge() throws {
        let set1: Set<Int> = [1,2]
        let set2: Set<Int> = [1,2,4]
        let ancestor: Set<Int> = [1,2,3]
        let result = try merger.merge(set1, withSubordinate: set2, commonAncestor: ancestor)
        #expect(result == Set<Int>([1,2,4]))
    }
    
}
