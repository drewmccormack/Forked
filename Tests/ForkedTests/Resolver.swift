import Testing
@testable import Forked

struct ResolverSuite {

    @Test func choosesMostRecent() throws {
        let resolver = Resolver<Int>()
        let a: Commit<Int> = .init(content: .resource(0), version: .init(count: 0))
        let c1: Commit<Int> = .init(content: .resource(1), version: .init(count: 1))
        let c2: Commit<Int> = .init(content: .resource(2), version: .init(count: 1, timestamp: c1.version.timestamp.addingTimeInterval(0.001)))
        #expect(c1.version.timestamp < c2.version.timestamp)
        let commits = ConflictingCommits(commits: (c1,c2))
        let m = try resolver.mergedContent(forConflicting: commits, withCommonAncestor: a)
        #expect(m == .resource(2))
    }
    
}
