import Testing
@testable import ForkedMerge

struct DictionaryMergerSuite {
    
    let merger = DictionaryMerger<String, Int>()
    
    @Test func basicMerge() throws {
        let ancestor: [String: Int] = ["a": 1, "b": 2, "d": 5]
        let dict2: [String: Int] = ["a": 1, "b": 3, "c": 4]
        let dict1: [String: Int] = ["a": 1, "b": 2]
        let result = try merger.merge(dict1, withOlderConflicting: dict2, commonAncestor: ancestor)
        #expect(result == ["a": 1, "b": 3, "c": 4])
    }
    
    @Test func noAncestor() throws {
        let dict1: [String: Int] = ["a": 1, "b": 2]
        let dict2: [String: Int] = ["c": 3, "d": 4]
        let result1 = try merger.merge(dict1, withOlderConflicting: dict2, commonAncestor: nil)
        #expect(result1 == dict1)
        let result2 = try merger.merge(dict2, withOlderConflicting: dict1, commonAncestor: nil)
        #expect(result2 == dict2)
    }
    
    @Test func conflictingUpdates() throws {
        let ancestor: [String: Int] = ["a": 5, "b": 20, "d": 40]
        let dict2: [String: Int] = ["a": 15, "b": 20, "c": 30]
        let dict1: [String: Int] = ["a": 10, "b": 20]
        let result = try merger.merge(dict1, withOlderConflicting: dict2, commonAncestor: ancestor)
        #expect(result == ["a": 10, "b": 20, "c": 30])
    }
    
    @Test func fullOverlap() throws {
        let dict1: [String: Int] = ["a": 1, "b": 2, "c": 3]
        let dict2: [String: Int] = ["a": 1, "b": 2, "c": 3]
        let ancestor: [String: Int] = ["a": 1, "b": 2, "c": 3]
        let result = try merger.merge(dict1, withOlderConflicting: dict2, commonAncestor: ancestor)
        #expect(result == dict1) // Should be identical since no changes occurred
    }
    
    @Test func emptyAncestor() throws {
        let ancestor: [String: Int] = [:]
        let dict2: [String: Int] = ["c": 3, "d": 4]
        let dict1: [String: Int] = ["a": 1, "b": 2]
        let result = try merger.merge(dict1, withOlderConflicting: dict2, commonAncestor: ancestor)
        #expect(result == ["a": 1, "b": 2, "c": 3, "d": 4])
    }
    
    @Test func mergingWithMergableValues() throws {
        let merger = DictionaryMerger<Int, MergeableArray<Int>>()
        let ancestor: [Int:MergeableArray<Int>] = [0 : MergeableArray<Int>([1, 2, 3])]
        var dict1 = ancestor
        dict1[0]!.append(4)
        var dict2 = ancestor
        dict2[0]!.append(5)
        let newDict = try merger.merge(dict1, withOlderConflicting: dict2, commonAncestor: ancestor)
        #expect(newDict[0]!.values == [1, 2, 3, 4, 5])
    }
    
}
