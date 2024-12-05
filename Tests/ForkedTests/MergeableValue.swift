import Testing
import Foundation
import Forked
@testable import ForkedMerge

struct MergeableValueSuite {
    
    let ancestor: MergeableValue<Int> = .init(0)
    var a: MergeableValue<Int>
    var b: MergeableValue<Int>
    
    init() {
        a = ancestor
        a.value = 1
        b = ancestor
        usleep(10) // Add this ensure no timestamp collision
        b.value = 2
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
    
    @Test mutating func lastChangeWins() async throws {
        try? await Task.sleep(for: .milliseconds(10)) // Add this ensure no timestamp collision
        a.value = 3
        let c = try a.merged(withSubordinate: b, commonAncestor: ancestor)
        #expect(c.value == a.value)
    }
    
    @Test func idempotency() throws {
        let c = try a.merged(withSubordinate: b, commonAncestor: ancestor)
        let d = try c.merged(withSubordinate: b, commonAncestor: ancestor)
        let e = try c.merged(withSubordinate: a, commonAncestor: ancestor)
        #expect(c.value == d.value)
        #expect(c.value == e.value)
    }
    
    @Test func commutativity() throws {
        let c = try a.merged(withSubordinate: b, commonAncestor: ancestor)
        let d = try b.merged(withSubordinate: a, commonAncestor: ancestor)
        #expect(d.value == c.value)
    }
    
    @Test func associativity() throws {
        let c: MergeableValue<Int> = .init(3)
        let e = try a.merged(withSubordinate: b, commonAncestor: ancestor).merged(withSubordinate: c, commonAncestor: ancestor)
        let f = try a.merged(withSubordinate: try b.merged(withSubordinate: c, commonAncestor: ancestor), commonAncestor: ancestor)
        #expect(e.value == f.value)
    }
    
    @Test func codable() throws {
        let data = try! JSONEncoder().encode(a)
        let d = try! JSONDecoder().decode(MergeableValue<Int>.self, from: data)
        #expect(a.value == d.value)
    }
    
    @Test func mergeChoosesMostRecent() async throws {
        var r1: MergeableValue<Int> = .init(1)
        var r2: MergeableValue<Int> = r1
        try? await Task.sleep(for: .milliseconds(10)) // Add this ensure no timestamp collision
        r2.value = 2
        let r3 = try r2.merged(withSubordinate: r1, commonAncestor: r1)
        let r4 = try r1.merged(withSubordinate: r2, commonAncestor: r1)
        #expect(r3.value == r4.value)
        #expect(r3.value == 2)
        r1.value = 3
        let r5 = try r2.merged(withSubordinate: r1, commonAncestor: r1)
        #expect(r5.value == 3)
    }
    
    @Test func thatCommonAncestorIsIgnored() async throws {
        let r1: MergeableValue<Int> = .init(1)
        var r2: MergeableValue<Int> = r1
        try? await Task.sleep(for: .milliseconds(10)) // Add this ensure no timestamp collision
        r2.value = 2
        let r3 = try r2.merged(withSubordinate: r1, commonAncestor: r1)
        let r4 = try r1.merged(withSubordinate: r2, commonAncestor: ancestor)
        #expect(r3 == r4)
    }
    
}
