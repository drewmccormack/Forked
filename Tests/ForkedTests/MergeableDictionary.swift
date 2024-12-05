import Foundation
import Testing
import Forked
@testable import ForkedMerge

struct MergingDictionarySuite {

    let ancestor = MergeableDictionary<String, Int>()
    var a: MergeableDictionary<String, Int>
    var b: MergeableDictionary<String, Int>

    var dictOfSetsAncestor: MergeableDictionary<String, MergeableSet<Int>> = [:]
    var dictOfSetsA: MergeableDictionary<String, MergeableSet<Int>>
    var dictOfSetsB: MergeableDictionary<String, MergeableSet<Int>>
    
    init() {
        a = ancestor
        b = ancestor
        dictOfSetsA = dictOfSetsAncestor
        dictOfSetsB = dictOfSetsAncestor
    }

    @Test func initialCreation() {
        #expect(a.count == 0)
        #expect(dictOfSetsA.count == 0)
    }

    @Test mutating func inserting() {
        a["1"] = 1
        a["2"] = 2
        a["3"] = 3
        #expect(a.values.sorted() == [1,2,3])
        #expect(a.keys.sorted() == ["1", "2", "3"])
    }

    @Test mutating func replacing() {
        a["1"] = 1
        a["2"] = 2
        a["3"] = 3
        #expect(a["2"] == 2)

        a["2"] = 4
        #expect(a["2"] == 4)
    }

    @Test mutating func removing() {
        a["1"] = 1
        a["2"] = 2
        a["3"] = 3
        a["1"] = nil
        #expect(a.values.sorted() == [2, 3])
        #expect(a.keys.sorted() == ["2", "3"])
    }

    @Test mutating func interleavedInsertAndRemove() {
        a["1"] = 1
        a["2"] = 2
        a["3"] = 3
        
        a["2"] = nil
        #expect(a["2"] == nil)

        a["2"] = 4
        a["3"] = 5
        #expect(a["2"] == 4)
        #expect(a["3"] == 5)

        a["2"] = nil
        a["3"] = 6
        #expect(a["2"] == nil)
        #expect(a["3"] == 6)
    }

    @Test mutating func mergeOfInitiallyUnrelated() throws {
        a["1"] = 1
        a["2"] = 2
        a["3"] = 3
        a["6"] = 8

        b["1"] = 4
        b["1"] = nil
        b["1"] = 4
        b["2"] = 5
        b["3"] = 6
        b["4"] = 7

        let c = try a.merged(withSubordinate: b, commonAncestor: ancestor)
        #expect(c.values.sorted() == [4, 5, 6, 7, 8])
    }

    @Test mutating func multipleMerges() throws {
        a["1"] = 1
        a["2"] = 2
        a["3"] = 3

        b = try b.merged(withSubordinate: a, commonAncestor: ancestor)

        b["4"] = 4
        b["4"] = nil

        b["1"] = 10
        b["5"] = 11

        b["4"] = 12
        a["6"] = 12

        let c = try a.merged(withSubordinate: b, commonAncestor: ancestor)
        #expect(c.values.sorted() == [2, 3, 10, 11, 12, 12])
        #expect(c.keys.sorted() == ["1", "2", "3", "4", "5", "6"])
        #expect(c["1"] == 10)
        #expect(c["4"] == 12)
        #expect(c["6"] == 12)
    }

    @Test mutating func idempotency() throws {
        a["1"] = 1
        a["2"] = 2
        a["3"] = 3
        a["2"] = nil

        b["1"] = 4
        b["1"] = nil
        b["1"] = 4
        b["3"] = 6

        let c = try a.merged(withSubordinate: b, commonAncestor: ancestor)
        let d = try c.merged(withSubordinate: b, commonAncestor: ancestor)
        let e = try c.merged(withSubordinate: a, commonAncestor: ancestor)
        #expect(c.dictionary == d.dictionary)
        #expect(c.dictionary == e.dictionary)
    }

    @Test mutating func commutivity() throws {
        a["1"] = 1
        a["2"] = 2
        a["3"] = 3
        a["2"] = nil

        b["1"] = 4
        b["1"] = nil
        b["3"] = 6

        let c = try a.merged(withSubordinate: b, commonAncestor: ancestor)
        let d = try b.merged(withSubordinate: a, commonAncestor: ancestor)
        #expect(c.dictionary == d.dictionary)
    }

    @Test mutating func associativity() throws {
        a["1"] = 1
        a["2"] = 2
        a["3"] = 3
        a["2"] = nil

        b["1"] = 4
        b["1"] = nil
        b["3"] = 6

        var c = a
        c["1"] = nil

        let e = try a.merged(withSubordinate: b, commonAncestor: ancestor).merged(withSubordinate: c, commonAncestor: ancestor)
        let f = try a.merged(withSubordinate: b.merged(withSubordinate: c, commonAncestor: ancestor), commonAncestor: ancestor)
        #expect(e.values == f.values)
    }

    @Test mutating func mergingOfMergeableSetValues() throws {
        dictOfSetsAncestor["3"] = .init()
        dictOfSetsA = dictOfSetsAncestor
        dictOfSetsB = dictOfSetsAncestor
        
        dictOfSetsA["1"] = .init(array: [1, 2, 3])
        dictOfSetsA["2"] = .init(array: [3, 4, 5])
        dictOfSetsA["3"] = .init(array: [1])

        dictOfSetsB["1"] = .init(array: [1, 2, 3, 4])
        dictOfSetsB["3"] = .init(array: [3, 4, 5])
        dictOfSetsB["1"] = nil
        dictOfSetsB["3"]!.insert(6)

        let dictOfSetC = try dictOfSetsA.merged(withSubordinate: dictOfSetsB, commonAncestor: dictOfSetsAncestor)
        #expect(dictOfSetC["3"]!.values == Set([1, 3, 4, 5, 6]))
        #expect(dictOfSetC["1"] == nil)
        #expect(dictOfSetC["2"]!.values == Set([3, 4, 5]))
    }
    
    @Test mutating func mergingOfMergeableValues() async throws {
        var a: MergeableDictionary<String, AccumulatingInt> = [:]
        
        a["1"] = .init(value: 1)
        a["2"] = .init(value: 2)
        a["3"] = .init(value: 3)
        a["4"] = .init(value: 0)
        
        let ancestor = a
        var b = a

        b["1"] = .init(value: 2)
        a["1"] = .init(value: 3)
        b["2"] = .init(value: 3)
        a["3"] = .init(value: 4)
        a["4"] = .init(value: 10)
        b["4"] = .init(value: 20)

        // Use mergable with common ancestor to merge values
        let c = try a.merged(withSubordinate: b, commonAncestor: ancestor)
        #expect(c["1"]!.value == 4)
        #expect(c["2"]!.value == 3)
        #expect(c["3"]!.value == 4)
        #expect(c["4"]!.value == 30)
    }

    @Test mutating func codable() throws {
        a["1"] = 1
        a["2"] = 2
        a["3"] = 3
        a["2"] = nil

        let data = try JSONEncoder().encode(a)
        let d = try JSONDecoder().decode(MergeableDictionary<String, Int>.self, from: data)
        #expect(d.dictionary == a.dictionary)
    }
}
