import Testing
@testable import Forked

struct UpdatingContentsSuite {
    let repo = AtomicRepository<Int>()
    let resource: ForkedResource<AtomicRepository<Int>>
    let fork = Fork(name: "fork")
    
    init() throws {
        resource = try ForkedResource(repository: repo)
        try resource.create(fork)
    }

    @Test func initialStateOfFork() throws {
        #expect(try resource.resource(of: fork) == nil)
        #expect(try resource.content(of: fork) == .none)
        try resource.mergeFromMain(into: fork)
        #expect(try !resource.mainVersion(differsFromVersionIn: fork))
    }
}
