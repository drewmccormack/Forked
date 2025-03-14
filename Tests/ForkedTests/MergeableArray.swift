import Testing
import Foundation
import Forked
@testable import ForkedMerge

struct MergeableArraySuite {
    
    var a: MergeableArray<Int> = []
    var b: MergeableArray<Int> = []
    
    @Test func initialCreation() {
        #expect(a.count == 0)
    }
    
    @Test mutating func appending() {
        a.append(1)
        a.append(2)
        a.append(3)
        #expect(a.values == [1, 2, 3])
    }
    
    @Test mutating func inserting() {
        a.insert(1, at: 0)
        a.insert(2, at: 0)
        a.insert(3, at: 0)
        #expect(a.values == [3, 2, 1])
    }
    
    @Test mutating func removing() {
        a.append(1)
        a.append(2)
        a.append(3)
        a.remove(at: 1)
        #expect(a.values == [1, 3])
        #expect(a.count == 2)
    }
    
    @Test mutating func interleavedInsertAndRemove() {
        a.append(1)
        a.append(2)
        a.remove(at: 1) // [1]
        a.append(3)
        a.remove(at: 0) // [3]
        a.append(1)
        a.append(2)
        a.remove(at: 1) // [3, 2]
        a.append(3)
        #expect(a.values == [3, 2, 3])
    }
    
    @Test mutating func mergeOfInitiallyUnrelated() throws {
        a.append(1)
        a.append(2)
        a.append(3)
        
        b.append(1)
        b.remove(at: 0)
        b.append(7)
        b.append(8)
        b.append(9)
        
        let c = try a.merged(withSubordinate: b, commonAncestor: a)
        #expect(c.values == [7, 8, 9, 1, 2, 3])
    }
    
    @Test mutating func mergeWithRemoves() throws {
        a.append(1)
        a.append(2)
        a.append(3)
        a.remove(at: 1)
        
        b.append(1)
        b.remove(at: 0)
        b.append(7)
        b.append(8)
        b.append(9)
        b.remove(at: 1)
        
        let d = try b.merged(withSubordinate: a, commonAncestor: a)
        #expect(d.values == [7, 9, 1, 3])
    }
    
    @Test mutating func multipleMerges() throws {
        a.append(1)
        a.append(2)
        a.append(3)
        
        b = try b.merged(withSubordinate: a, commonAncestor: a)
        
        b.insert(1, at: 0)
        b.remove(at: 0)
        
        b.insert(1, at: 0)
        b.append(5) // [1,1,2,3,5]
        
        a.append(6) // [1,2,3,6]
        
        #expect(try a.merged(withSubordinate: b, commonAncestor: a).values == [1, 1, 2, 3, 6, 5])
    }
    
    @Test mutating func idempotency() throws {
        a.append(1)
        a.append(2)
        a.append(3)
        a.remove(at: 1)
        
        b.append(1)
        b.remove(at: 0)
        b.append(7)
        b.append(8)
        b.append(9)
        b.remove(at: 1)
        
        let c = try a.merged(withSubordinate: b, commonAncestor: a)
        let d = try c.merged(withSubordinate: b, commonAncestor: a)
        let e = try c.merged(withSubordinate: a, commonAncestor: a)
        #expect(c.values == d.values)
        #expect(c.values == e.values)
    }
    
    @Test mutating func commutivity() throws {
        a.append(1)
        a.append(2)
        a.append(3)
        a.remove(at: 1)
        
        b.append(1)
        b.remove(at: 0)
        b.append(7)
        b.append(8)
        b.append(9)
        b.remove(at: 1)
        
        let c = try a.merged(withSubordinate: b, commonAncestor: a)
        let d = try b.merged(withSubordinate: a, commonAncestor: a)
        #expect(d.values == [7, 9, 1, 3])
        #expect(d.values == c.values)
    }
    
    @Test mutating func associativity() throws {
        a.append(1)
        a.append(2)
        a.remove(at: 1)
        a.append(3)
        
        b.append(5)
        b.append(6)
        b.append(7)

        var c: MergeableArray<Int> = [10, 11, 12]
        c.remove(at: 0)

        let e = try a.merged(withSubordinate: b, commonAncestor: a).merged(withSubordinate: c, commonAncestor: a)
        let f = try a.merged(withSubordinate: b.merged(withSubordinate: c, commonAncestor: a), commonAncestor: a)
        #expect(e.values == f.values)
    }
    
    @Test mutating func codable() throws {
        a.append(1)
        a.append(2)
        a.remove(at: 1)
        a.append(3)
        
        let data = try JSONEncoder().encode(a)
        let d = try JSONDecoder().decode(MergeableArray<Int>.self, from: data)
        #expect(d.values == a.values)
    }
    
    @Test mutating func mergeWithEmptyArray() throws {
        a.append(1)
        a.append(2)
        let c = try a.merged(withSubordinate: b, commonAncestor: a) // b is empty
        #expect(c.values == [1, 2])
    }

    @Test mutating func mergeEmptyArrayWithPopulatedArray() throws {
        b.append(5)
        b.append(6)
        let c = try a.merged(withSubordinate: b, commonAncestor: a) // a is empty
        #expect(c.values == [5, 6])
    }

    @Test mutating func mergingWithSelf() throws {
        a.append(1)
        a.append(2)
        let c = try a.merged(withSubordinate: a, commonAncestor: a) // Merging with itself
        #expect(c.values == a.values)
    }

    @Test mutating func duplicateInsertions() {
        a.append(1)
        a.append(1) // Duplicate insertions
        #expect(a.values == [1, 1])
    }

    @Test mutating func mergeWithInterleaving() throws {
        a.append(1)
        a.append(2)
        a.append(3)
        
        b.append(4)
        b.append(5)
        b.append(6)
        
        let c = try a.merged(withSubordinate: b, commonAncestor: a)
        #expect(c.values == [1, 2, 3, 4, 5, 6] || c.values == [4, 5, 6, 1, 2, 3])
    }

    @Test func entriesUniquelyIdentified() {
        struct Item: Identifiable, Equatable {
            let id: String
            let value: Int
        }
        
        var array = MergeableArray<Item>()
        
        // Add items in a specific order
        array.append(Item(id: "a", value: 1))
        array.append(Item(id: "b", value: 1))
        array.append(Item(id: "a", value: 2))  // Duplicate id, newer timestamp
        array.append(Item(id: "c", value: 1))
        array.append(Item(id: "b", value: 2))  // Duplicate id, newer timestamp
        
        let uniqued = array.entriesUniquelyIdentified()
        
        // Should keep most recent version of each id
        #expect(uniqued.count == 3)
        #expect(uniqued[0].id == "a")  // From position 2
        #expect(uniqued[1].id == "c")  // From position 3
        #expect(uniqued[2].id == "b")  // From position 4
        
        // Original array should be unchanged
        #expect(array.count == 5)
    }

    @Test func uniquelyIdentifiedFollowingMerge() throws {
        struct Item: Identifiable, Equatable {
            let id: String
            let value: Int
        }
        
        var array1 = MergeableArray<Item>()
        array1.append(Item(id: "a", value: 1))
        array1.append(Item(id: "b", value: 1))
        array1.append(Item(id: "c", value: 1))
        
        var array2 = array1
        array2.append(Item(id: "a", value: 2))  // Update 'a'
        array2.append(Item(id: "d", value: 1))  // Add new item
        
        let merged = try array2.merged(withSubordinate: array1, commonAncestor: array1)
        let uniqued = merged.entriesUniquelyIdentified()
        
        // Should have 4 items with most recent values
        #expect(uniqued.count == 4)
        #expect(uniqued[0].id == "b" && uniqued[0].value == 1)  // Updated value
        #expect(uniqued[1].id == "c" && uniqued[1].value == 1)  // Original value
        #expect(uniqued[2].id == "a" && uniqued[2].value == 1)  // Original value, since values earlier in the array are favored when there are dupes
        #expect(uniqued[3].id == "d" && uniqued[3].value == 1)  // New value
    }

    @Test func mergingMergeableIdentifiableElements() throws {
        struct Item: Identifiable, Equatable, Mergeable {
            let id: String
            let value: Int
            func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                Self(id: id, value: value + other.value - commonAncestor.value)
            }
        }
        
        let ancestor = MergeableArray<Item>([.init(id: "a", value: 1), .init(id: "b", value: 2), .init(id: "c", value: 3)])
        var a = ancestor
        var b = ancestor
        
        a.append(.init(id: "d", value: 1))
        a[0] = .init(id: "a", value: 2)
        b[0] = .init(id: "a", value: 4)
        
        let merged = try a.merged(withSubordinate: b, commonAncestor: ancestor)
        let reverseMerged = try a.merged(withSubordinate: b, commonAncestor: ancestor)
        #expect(merged.values == reverseMerged.values)
        #expect(merged.values.map(\.value) == [5, 2, 3, 1])
    }
}
