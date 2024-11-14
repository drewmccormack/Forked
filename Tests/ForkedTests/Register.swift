import Testing
import Foundation
@testable import Forked

struct RegisterSuite {
    
    var a: Register<Int>
    var b: Register<Int>
    
    init() {
        a = .init(1)
        b = .init(2)
    }
    
    @Test func testInitialCreation() {
        #expect(a.value == 1)
    }
    
    @Test mutating func testSettingValue() {
        a.value = 2
        #expect(a.value == 2)
        a.value = 3
        #expect(a.value == 3)
    }
    
    @Test func testMergeOfInitiallyUnrelated() throws {
        let c = try a.merged(withOlderConflicting: b, commonAncestor: nil)
        #expect(c.value == b.value)
    }
    
    @Test mutating func testLastChangeWins() throws {
        a.value = 3
        let c = try a.merged(withOlderConflicting: b, commonAncestor: nil)
        #expect(c.value == a.value)
    }
    
    @Test func testIdempotency() throws {
        let c = try a.merged(withOlderConflicting: b, commonAncestor: nil)
        let d = try c.merged(withOlderConflicting: b, commonAncestor: nil)
        let e = try c.merged(withOlderConflicting: a, commonAncestor: nil)
        #expect(c.value == d.value)
        #expect(c.value == e.value)
    }
    
    @Test func testCommutativity() throws {
        let c = try a.merged(withOlderConflicting: b, commonAncestor: nil)
        let d = try b.merged(withOlderConflicting: a, commonAncestor: nil)
        #expect(d.value == c.value)
    }
    
    @Test func testAssociativity() throws {
        let c: Register<Int> = .init(3)
        let e = try a.merged(withOlderConflicting: b, commonAncestor: nil).merged(withOlderConflicting: c, commonAncestor: nil)
        let f = try a.merged(withOlderConflicting: try b.merged(withOlderConflicting: c, commonAncestor: nil), commonAncestor: nil)
        #expect(e.value == f.value)
    }
    
    @Test func testCodable() throws {
        let data = try! JSONEncoder().encode(a)
        let d = try! JSONDecoder().decode(Register<Int>.self, from: data)
        #expect(a.value == d.value)
    }
    
    @Test func testMergeChoosesMostRecent() throws {
        var r1: Register<Int> = .init(1)
        var r2: Register<Int> = r1
        r2.value = 2
        let r3 = try r2.merged(withOlderConflicting: r1, commonAncestor: r1)
        let r4 = try r1.merged(withOlderConflicting: r2, commonAncestor: r1)
        #expect(r3 == r4)
        #expect(r3.value == 2)
        r1.value = 3
        let r5 = try r2.merged(withOlderConflicting: r1, commonAncestor: r1)
        #expect(r5.value == 3)
    }
    
    @Test func testThatCommonAncestorIsIgnored() throws {
        let r1: Register<Int> = .init(1)
        var r2: Register<Int> = r1
        r2.value = 2
        let r3 = try r2.merged(withOlderConflicting: r1, commonAncestor: r1)
        let r4 = try r1.merged(withOlderConflicting: r2, commonAncestor: nil)
        #expect(r3 == r4)
    }
    
}
