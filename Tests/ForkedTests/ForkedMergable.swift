import Testing
@testable import Forked

struct Pair: Equatable, Mergeable {
    var a: Int
    var b: Int

    func merged(withSubordinate other: Pair, commonAncestor: Pair) throws -> Pair {
        var result = self
        if self.a == commonAncestor.a && other.a != commonAncestor.a {
            result.a = other.a
        }
        if self.b == commonAncestor.b && other.b != commonAncestor.b {
            result.b = other.b
        }
        return result
    }
    
}

struct MergingMergeableSuite {
    let resource = QuickFork<Pair>()
    let fork = Fork(name: "fork")
    
    init() throws {
        try resource.create(fork)
    }
    
    @Test func mergeWithTwoNone() throws {
        let p = Pair(a: 1, b: 2)
        try resource.update(.main, with: p)
        try resource.mergeFromMain(into: fork)
        let r = try resource.mostRecentCommit(of: fork).content.resource
        #expect(r == p)
    }
    
    @Test func mergeWithNone() throws {
        let p1 = Pair(a: 1, b: 2)
        try resource.update(.main, with: p1)
        try resource.update(fork, with: .none)
        try #require(resource.mergeFromMain(into: fork) == .resolveConflict)
        let r = try resource.mostRecentCommit(of: fork).content.resource
        #expect(r == p1)
    }
    
    @Test func mergeWithTwoValues() throws {
        let p1 = Pair(a: 1, b: 2)
        try resource.update(.main, with: p1)
        try resource.syncAllForks()
        let p2 = Pair(a: 2, b: 2)
        try resource.update(.main, with: p2)
        let p3 = Pair(a: 1, b: 3)
        try resource.update(fork, with: p3)
        try #require(resource.mergeFromMain(into: fork) == .resolveConflict)
        let r = try resource.mostRecentCommit(of: fork).content.resource
        #expect(r == Pair(a: 2, b: 3)) 
    }
    
    @Test
    func syncingForksWithMergeable() throws {
        let p1 = Pair(a: 1, b: 2)
        try resource.update(.main, with: p1)
        try resource.syncAllForks()
        let p2 = Pair(a: 2, b: 2)
        try resource.update(.main, with: p2)
        let p3 = Pair(a: 1, b: 3)
        try resource.update(fork, with: p3)
        #expect(try resource.mostRecentVersion(of: fork).count == 3)
        #expect(try resource.mostRecentVersion(of: .main).count == 2)
        try resource.syncMain(with: [fork])
        #expect(try resource.mostRecentVersion(of: fork).count == 4)
        #expect(try resource.mostRecentVersion(of: .main).count == 4)
        #expect(try resource.mostRecentVersion(of: .main) == resource.mostRecentVersion(of: fork))
        #expect(try resource.resource(of: .main) == Pair(a: 2, b: 3))
    }
    
    @Test func salvagingWhenBootstrapping() async throws {
        struct SalvagablePair: Equatable, Mergeable {
            var a: Int
            var b: Int

            func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                var result = self
                if self.a == commonAncestor.a && other.a != commonAncestor.a {
                    result.a = other.a
                }
                if self.b == commonAncestor.b && other.b != commonAncestor.b {
                    result.b = other.b
                }
                return result
            }
            
            func salvaging(from other: SalvagablePair) throws -> SalvagablePair {
                other
            }
        }
        
        do {
            let p1 = Pair(a: 1, b: 2)
            try resource.update(.main, with: p1)
            let p2 = Pair(a: 2, b: 1)
            try resource.update(fork, with: p2)
            try resource.mergeIntoMain(from: fork)
            let m1 = try resource.value(in: .main)!
            #expect(m1 == p2) // fork is dominant because updated last
        }
        
        do {
            let resource = QuickFork<SalvagablePair>()
            try resource.create(fork)
            
            let p1 = SalvagablePair(a: 1, b: 2)
            try resource.update(.main, with: p1)
            let p2 = SalvagablePair(a: 2, b: 1)
            try resource.update(fork, with: p2)
            try resource.mergeIntoMain(from: fork)
            let m1 = try resource.value(in: .main)!
            #expect(m1 == p1) // "salvaged" chooses other
        }
    }
}
