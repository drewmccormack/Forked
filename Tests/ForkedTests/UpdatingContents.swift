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
    
    @Test func versionsDuringUpdates() throws {
        #expect(try resource.mostRecentVersion(of: fork).timestamp == .distantPast)
        let v1 = try resource.update(fork, with: 1)
        let v2 = try resource.update(fork, with: 2)
        let m = try resource.mostRecentVersion(of: .main)
        #expect(m != v1)
        #expect(m != v2)
        #expect(v1 != v2)
        #expect(v1.count == 1)
        #expect(v2.count == 2)
        #expect(v1.timestamp < v2.timestamp)
        #expect(m.timestamp == .distantPast)
        #expect(m.count == 0)
    }
    
    @Test func multipleUpdates() throws {
        try resource.update(fork, with: 1)
        #expect(try resource.resource(of: fork) == 1)
        try resource.update(fork, with: 2)
        #expect(try resource.resource(of: fork) == 2)
        #expect(try resource.resource(of: .main) == .none)
        #expect(try resource.repository.versions(storedIn: fork).count == 2)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
    }
    
    @Test func versionsIncrement() throws {
        let v1 = try resource.mostRecentVersion(of: fork)
        try resource.update(fork, with: 1)
        let v2 = try resource.mostRecentVersion(of: fork)
        #expect(v2 > v1)
        #expect(v2.timestamp > v1.timestamp)
        #expect(v2.count == v1.count+1)
    }
}
