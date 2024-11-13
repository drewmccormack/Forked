import Testing
@testable import Forked

struct ManipulatingForksSuite {
    @Test func creatingEmptyResource() throws {
        let repo = AtomicRepository<Int>()
        let resource = try ForkedResource(repository: repo)
        try #require(resource.forks.count == 1)
        #expect(resource.forks.contains(.main))
    }
    
    @Test func creatingFork() throws {
        let repo = AtomicRepository<Int>()
        let resource = try ForkedResource(repository: repo)
        let fork = Fork(name: "Test")
        try resource.create(fork)
        try #require(resource.forks.count == 2)
        #expect(resource.forks.contains(fork))
        #expect(resource.forks.contains(.main))
    }
    
    @Test func creatingExistingForkFails() throws {
        let repo = AtomicRepository<Int>()
        let resource = try ForkedResource(repository: repo)
        let fork = Fork(name: "Test")
        try resource.create(fork)
        #expect(throws: (Forked.Error).self) {
            try resource.create(Fork(name: "Test"))
        }
    }
    
    @Test func creatingMainForkFails() throws {
        let repo = AtomicRepository<Int>()
        let resource = try ForkedResource(repository: repo)
        #expect(throws: (Forked.Error).self) {
            try resource.create(.main)
        }
    }
    
    @Test func deletingFork() throws {
        let repo = AtomicRepository<Int>()
        let resource = try ForkedResource(repository: repo)
        let fork1 = Fork(name: "Test1")
        try resource.create(fork1)
        let fork2 = Fork(name: "Test2")
        try resource.create(fork2)
        try #require(resource.forks.count == 3)
        #expect(resource.forks.contains(fork1))
        #expect(resource.forks.contains(fork2))
        #expect(resource.forks.contains(.main))
        try resource.delete(fork1)
        try #require(resource.forks.count == 2)
        #expect(!resource.forks.contains(fork1))
        #expect(resource.forks.contains(fork2))
        #expect(resource.forks.contains(.main))
    }
    
    @Test func deletingMainFails() throws {
        let repo = AtomicRepository<Int>()
        let resource = try ForkedResource(repository: repo)
        #expect(throws: (Forked.Error).self) {
            try resource.delete(.main)
        }
    }
    
    @Test func deletingNonexistentForkFails() throws {
        let repo = AtomicRepository<Int>()
        let resource = try ForkedResource(repository: repo)
        #expect(throws: (Forked.Error).self) {
            try resource.delete(Fork(name: "None"))
        }
    }
}
