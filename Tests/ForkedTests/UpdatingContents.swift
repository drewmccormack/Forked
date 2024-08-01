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
        #expect(try !resource.mainVersion(differsFromVersionIn: fork))
        try #require(resource.resource(of: fork) == nil)
        try #require(resource.content(of: fork) == .none)
    }
    
    @Test func singleUpdate() throws {
        try resource.update(fork, with: 1)
        #expect(try resource.mainVersion(differsFromVersionIn: fork))
        #expect(try resource.resource(of: fork) == 1)
        #expect(try resource.resource(of: .main) == .none)
        #expect(try resource.repository.versions(storedIn: fork).count == 2)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
    }
}
