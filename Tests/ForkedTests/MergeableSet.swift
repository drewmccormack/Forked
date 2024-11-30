import Foundation
import Testing
@testable import ForkedMerge

struct MergingSetSuite {
    
    var a: MergeableSet<Int> = []
    var b: MergeableSet<Int> = []
    
    @Test func initialCreation() {
        #expect(a.count == 0)
    }
    
    @Test mutating func appending() {
        a.insert(1)
        a.insert(2)
        a.insert(3)
        #expect(a.values == [1,2,3])
    }
    
    @Test mutating func inserting() {
        a.insert(1)
        a.insert(2)
        a.insert(3)
        #expect(a.values == Set([3,2,1]))
    }
    
    @Test mutating func removing() {
        a.insert(1)
        a.insert(2)
        a.insert(3)
        a.remove(2)
        #expect(a.values == Set([1,3]))
        #expect(a.count == 2)
    }
    
    @Test mutating func setting() {
        a.insert(1)
        a.insert(2)
        #expect(a.values == Set([1,2]))
        a.values = [3,4,5]
        #expect(a.values == Set([3,4,5]))
    }
    
    @Test mutating func interleavedInsertAndRemove() {
        a.insert(1)
        a.insert(2)
        a.remove(1) // 2
        a.insert(3)
        a.remove(2) // 3
        a.insert(1)
        a.insert(2) // 1,2,3
        a.remove(1) // 2,3
        a.insert(3) // 2,3
        #expect(a.values == Set([2,3]))
    }
    
    @Test mutating func mergeOfInitiallyUnrelated() throws {
        a.insert(1)
        a.insert(2)
        a.insert(3)
        
        b.insert(10)
        b.remove(10)
        b.insert(7)
        b.insert(8)
        b.insert(9)
        
        let c = try a.merged(with: b)
        #expect(c.values == Set([7,8,9,1,2,3]))
    }
    
    @Test mutating func mergeWithRemoves() throws {
        a.insert(1)
        a.insert(2)
        a.insert(3)
        a.remove(1) // 2,3
        
        b.insert(1)
        b.remove(0)
        b.insert(7)
        b.insert(8)
        b.insert(9)
        b.remove(1) // 7,8,9
        
        let d = try b.merged(with: a)
        #expect(d.values == Set([2,3,7,8,9]))
    }

    @Test mutating func multipleMerges() throws {
        a.values = [1,2,3]
        
        b = try b.merged(with: a)
        
        b.insert(10)
        b.remove(10)
        
        b.insert(1)
        b.insert(5) // [1,2,3,5]
        
        a.insert(6) // [1,2,3,6]
        
        #expect(try a.merged(with: b).values == Set([1,2,3,5,6]))
    }
    
    @Test mutating func idempotency() throws {
        a.insert(1)
        a.insert(2)
        a.insert(3)
        a.remove(1)
        
        b.insert(1)
        b.remove(1)
        b.insert(7)
        b.insert(8)
        b.insert(9)
        b.remove(8)
        
        let c = try a.merged(with: b)
        let d = try c.merged(with: b)
        let e = try c.merged(with: a)
        #expect(c.values == d.values)
        #expect(c.values == e.values)
    }
    
    @Test mutating func commutivity() throws {
        a.insert(1)
        a.insert(2)
        a.insert(3)
        a.remove(2)
        
        b.insert(10)
        b.remove(10)
        b.insert(7)
        b.insert(8)
        b.insert(9)
        b.remove(8)
        
        let c = try a.merged(with: b)
        let d = try b.merged(with: a)
        #expect(d.values == Set([7,9,1,3]))
        #expect(d.values == c.values)
    }
    
    @Test mutating func associativity() throws {
        a.insert(1)
        a.insert(2)
        a.remove(2)
        a.insert(3)
        
        b.insert(5)
        b.insert(6)
        b.insert(7)

        var c: MergeableSet<Int> = [10,11,12]
        c.remove(10)

        let e = try a.merged(with: b).merged(with: c)
        let f = try a.merged(with: b.merged(with: c))
        #expect(e.values == f.values)
    }
    
    @Test mutating func codable() throws {
        a.insert(1)
        a.insert(2)
        a.remove(2)
        a.insert(3)
        
        let data = try JSONEncoder().encode(a)
        let d = try JSONDecoder().decode(MergeableSet<Int>.self, from: data)
        #expect(d.values == a.values)
    }
    
    @Test mutating func mergingWithEmptySet() throws {
        a.insert(1)
        a.insert(2)
        let c = try a.merged(with: b) // b is empty
        #expect(c.values == Set([1,2]))
    }

    @Test mutating func mergingEmptySetWithPopulatedSet() throws {
        b.insert(5)
        b.insert(6)
        let c = try a.merged(with: b) // a is empty
        #expect(c.values == Set([5,6]))
    }

    @Test mutating func duplicateInserts() {
        a.insert(1)
        a.insert(1) // Duplicate insert
        #expect(a.count == 1)
        #expect(a.values == Set([1]))
    }

    @Test mutating func mergingWithSelf() throws {
        a.insert(1)
        a.insert(2)
        let c = try a.merged(with: a) // Merging with itself
        #expect(c.values == a.values)
    }

    @Test mutating func removingNonExistentElement() {
        a.insert(1)
        a.insert(2)
        a.remove(3) // Attempt to remove a non-existent element
        #expect(a.values == Set([1,2]))
    }

    @Test mutating func mergeWithConflictingChanges() async throws {
        a.insert(1)
        a.insert(2)
        a.remove(1) // 2
        
        try await Task.sleep(for: .milliseconds(1))
        
        b.insert(1)
        b.insert(3) // 1,3

        let c = try a.merged(with: b)
        #expect(c.values == Set([1,2,3]))
    }

    @Test mutating func largeSetMerge() throws {
        for i in 1...1000 {
            a.insert(i)
        }
        for i in 500...1500 {
            b.insert(i)
        }
        let c = try a.merged(with: b)
        #expect(c.values == Set((1...1500)))
    }
}
