import Testing
import Foundation
import Forked
@testable import ForkedMerge

struct MergableArraySuite {
    
    var a: MergableArray<Int> = []
    var b: MergableArray<Int> = []
    
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
    
    @Test mutating func mergeOfInitiallyUnrelated() {
        a.append(1)
        a.append(2)
        a.append(3)
        
        b.append(1)
        b.remove(at: 0)
        b.append(7)
        b.append(8)
        b.append(9)
        
        let c = a.merged(with: b)
        #expect(c.values == [7, 8, 9, 1, 2, 3])
    }
    
    @Test mutating func mergeWithRemoves() {
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
        
        let d = b.merged(with: a)
        #expect(d.values == [7, 9, 1, 3])
    }
    
    @Test mutating func multipleMerges() {
        a.append(1)
        a.append(2)
        a.append(3)
        
        b = b.merged(with: a)
        
        b.insert(1, at: 0)
        b.remove(at: 0)
        
        b.insert(1, at: 0)
        b.append(5) // [1,1,2,3,5]
        
        a.append(6) // [1,2,3,6]
        
        #expect(a.merged(with: b).values == [1, 1, 2, 3, 5, 6])
    }
    
    @Test mutating func idempotency() {
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
        
        let c = a.merged(with: b)
        let d = c.merged(with: b)
        let e = c.merged(with: a)
        #expect(c.values == d.values)
        #expect(c.values == e.values)
    }
    
    @Test mutating func commutivity() {
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
        
        let c = a.merged(with: b)
        let d = b.merged(with: a)
        #expect(d.values == [7, 9, 1, 3])
        #expect(d.values == c.values)
    }
    
    @Test mutating func associativity() {
        a.append(1)
        a.append(2)
        a.remove(at: 1)
        a.append(3)
        
        b.append(5)
        b.append(6)
        b.append(7)

        var c: MergableArray<Int> = [10, 11, 12]
        c.remove(at: 0)

        let e = a.merged(with: b).merged(with: c)
        let f = a.merged(with: b.merged(with: c))
        #expect(e.values == f.values)
    }
    
    @Test mutating func codable() throws {
        a.append(1)
        a.append(2)
        a.remove(at: 1)
        a.append(3)
        
        let data = try JSONEncoder().encode(a)
        let d = try JSONDecoder().decode(MergableArray<Int>.self, from: data)
        #expect(d.values == a.values)
    }
}
