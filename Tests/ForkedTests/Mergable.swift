import Testing
@testable import Forked

struct Pair: Equatable, Mergable {
    var a: Int
    var b: Int

    func merged(withOlderConflicting other: Pair, commonAncestor: Pair?) throws -> Pair {
        guard let commonAncestor else { return self }
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

struct MergingMergableSuite {
    typealias Repo = AtomicRepository<Pair>
    let repo = Repo()
    let resource: ForkedResource<Repo>
    let fork = Fork(name: "fork")
    
    init() throws {
        resource = try ForkedResource(repository: repo)
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
        let p = Pair(a: 1, b: 2)
        try resource.update(.main, with: p)
        try resource.update(fork, with: .none)
        try resource.mergeFromMain(into: fork) // == .resolveConflict)
        let r = try resource.mostRecentCommit(of: fork).content.resource
        #expect(r == p)
    }
}
