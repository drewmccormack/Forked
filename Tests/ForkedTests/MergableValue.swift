import Testing
import Foundation
import Forked
@testable import ForkedMerge

struct MergableValueSuite {
    
    var a: MergableValue<Int>
    var b: MergableValue<Int>
    
    init() {
        a = .init(1)
        usleep(10) // Add this ensure no timestamp collision
        b = .init(2)
        usleep(10) // Add this ensure no timestamp collision
    }
    
    @Test func initialCreation() {
        #expect(a.value == 1)
    }
    
    @Test mutating func settingValue() {
        a.value = 2
        #expect(a.value == 2)
        a.value = 3
        #expect(a.value == 3)
    }
    
    @Test func mergeOfInitiallyUnrelated() throws {
        let c = try a.merged(withOlderConflicting: b, commonAncestor: nil)
        #expect(c.value == b.value)
    }
    
    @Test mutating func lastChangeWins() async throws {
        try? await Task.sleep(for: .milliseconds(10)) // Add this ensure no timestamp collision
        a.value = 3
        let c = try a.merged(withOlderConflicting: b, commonAncestor: nil)
        #expect(c.value == a.value)
    }
    
    @Test func idempotency() throws {
        let c = try a.merged(withOlderConflicting: b, commonAncestor: nil)
        let d = try c.merged(withOlderConflicting: b, commonAncestor: nil)
        let e = try c.merged(withOlderConflicting: a, commonAncestor: nil)
        #expect(c.value == d.value)
        #expect(c.value == e.value)
    }
    
    @Test func commutativity() throws {
        let c = try a.merged(withOlderConflicting: b, commonAncestor: nil)
        let d = try b.merged(withOlderConflicting: a, commonAncestor: nil)
        #expect(d.value == c.value)
    }
    
    @Test func associativity() throws {
        let c: MergableValue<Int> = .init(3)
        let e = try a.merged(withOlderConflicting: b, commonAncestor: nil).merged(withOlderConflicting: c, commonAncestor: nil)
        let f = try a.merged(withOlderConflicting: try b.merged(withOlderConflicting: c, commonAncestor: nil), commonAncestor: nil)
        #expect(e.value == f.value)
    }
    
    @Test func codable() throws {
        let data = try! JSONEncoder().encode(a)
        let d = try! JSONDecoder().decode(MergableValue<Int>.self, from: data)
        #expect(a.value == d.value)
    }
    
    @Test func mergeChoosesMostRecent() async throws {
        var r1: MergableValue<Int> = .init(1)
        var r2: MergableValue<Int> = r1
        try? await Task.sleep(for: .milliseconds(10)) // Add this ensure no timestamp collision
        r2.value = 2
        let r3 = try r2.merged(withOlderConflicting: r1, commonAncestor: r1)
        let r4 = try r1.merged(withOlderConflicting: r2, commonAncestor: r1)
        #expect(r3.value == r4.value)
        #expect(r3.value == 2)
        r1.value = 3
        let r5 = try r2.merged(withOlderConflicting: r1, commonAncestor: r1)
        #expect(r5.value == 3)
    }
    
    @Test func thatCommonAncestorIsIgnored() async throws {
        let r1: MergableValue<Int> = .init(1)
        var r2: MergableValue<Int> = r1
        try? await Task.sleep(for: .milliseconds(10)) // Add this ensure no timestamp collision
        r2.value = 2
        let r3 = try r2.merged(withOlderConflicting: r1, commonAncestor: r1)
        let r4 = try r1.merged(withOlderConflicting: r2, commonAncestor: nil)
        #expect(r3 == r4)
    }
    
}
