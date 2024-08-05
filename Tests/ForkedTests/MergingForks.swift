import Testing
@testable import Forked

struct MergingForksSuite {
    let repo = AtomicRepository<Int>()
    let resource: ForkedResource<AtomicRepository<Int>>
    let fork = Fork(name: "fork")
    
    init() throws {
        resource = try ForkedResource(repository: repo)
        try resource.create(fork)
    }
    
    @Test func mergingInitialState() throws {
        #expect(try resource.repository.versions(storedIn: fork).count == 1)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
        #expect(try resource.mergeFromMain(into: fork) == .none)
        #expect(try resource.repository.versions(storedIn: fork).count == 1)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
        #expect(try resource.mergeIntoMain(from: fork) == .none)
        #expect(try resource.repository.versions(storedIn: fork).count == 1)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
    }
    
    @Test(arguments: [[1], [1,2], [1,2,3], [1,1]])
    func mergingWithForkUpdated(values: [Int]) throws {
        for v in values {
            try resource.update(fork, with: v)
        }
        #expect(try resource.repository.versions(storedIn: fork).count == 2)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
        #expect(try resource.mergeFromMain(into: fork) == .none)
        #expect(try resource.repository.versions(storedIn: fork).count == 2)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
        #expect(try resource.mergeIntoMain(from: fork) == .fastForward)
        #expect(try resource.repository.versions(storedIn: fork).count == 0)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
    }
    
    @Test(arguments: [[1], [1,2], [1,2,3], [1,1]])
    func mergingWithMainUpdated(values: [Int]) throws {
        for v in values {
            try resource.update(.main, with: v)
        }
        #expect(try resource.repository.versions(storedIn: fork).count == 1)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
        #expect(try resource.mergeIntoMain(from: fork) == .none)
        #expect(try resource.repository.versions(storedIn: fork).count == 1)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
        #expect(try resource.mergeFromMain(into: fork) == .fastForward)
        #expect(try resource.repository.versions(storedIn: fork).count == 0)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
    }
    
    @Test
    func syncingForks() throws {
        try resource.update(fork, with: 1)
        try resource.update(.main, with: 2)
        #expect(try resource.mostRecentVersion(of: fork).count == 1)
        #expect(try resource.mostRecentVersion(of: .main).count == 2)
        try resource.syncMain(with: fork)
        #expect(try resource.mostRecentVersion(of: fork).count == 3)
        #expect(try resource.mostRecentVersion(of: .main).count == 3)
        #expect(try resource.mostRecentVersion(of: .main) == resource.mostRecentVersion(of: fork))
        #expect(try resource.resource(of: .main) == 2)
    }
    
    @Test func mergingMultipleForks() throws {
        let otherFork = Fork(name: "otherFork")
        try resource.create(otherFork)
        try resource.update(.main, with: 1)
        #expect(try resource.repository.versions(storedIn: fork).count == 1)
        #expect(try resource.repository.versions(storedIn: otherFork).count == 1)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
        try resource.update(fork, with: 2)
        #expect(try resource.repository.versions(storedIn: fork).count == 2)
        #expect(try resource.repository.versions(storedIn: otherFork).count == 1)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
        try resource.update(otherFork, with: 3)
        try resource.update(otherFork, with: 4)
        #expect(try resource.repository.versions(storedIn: fork).count == 2)
        #expect(try resource.repository.versions(storedIn: otherFork).count == 2)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
        #expect(try resource.mergeIntoMain(from: fork) == .resolveConflict)
        #expect(try resource.repository.versions(storedIn: fork).count == 1)
        #expect(try resource.repository.versions(storedIn: otherFork).count == 2)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
        #expect(try resource.mergeFromMain(into: fork) == .fastForward)
        #expect(try resource.repository.versions(storedIn: fork).count == 0)
        #expect(try resource.repository.versions(storedIn: otherFork).count == 2)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
        #expect(try resource.mergeFromMain(into: otherFork) == .resolveConflict)
        #expect(try resource.repository.versions(storedIn: fork).count == 0)
        #expect(try resource.repository.versions(storedIn: otherFork).count == 2)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
        #expect(try resource.mergeIntoMain(from: otherFork) == .fastForward)
        #expect(try resource.repository.versions(storedIn: fork).count == 1)
        #expect(try resource.repository.versions(storedIn: otherFork).count == 0)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
        #expect(try resource.mergeFromMain(into: fork) == .fastForward)
        #expect(try resource.repository.versions(storedIn: fork).count == 0)
        #expect(try resource.repository.versions(storedIn: otherFork).count == 0)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
        #expect(try resource.mergeFromMain(into: fork) == .none)
        #expect(try resource.mergeFromMain(into: otherFork) == .none)
        #expect(try resource.mergeIntoMain(from: fork) == .none)
        #expect(try resource.mergeIntoMain(from: otherFork) == .none)
        #expect(try resource.repository.versions(storedIn: fork).count == 0)
        #expect(try resource.repository.versions(storedIn: otherFork).count == 0)
        #expect(try resource.repository.versions(storedIn: .main).count == 1)
    }
    
    @Test func emptyForkGetStoresCommonAncestor() throws {
        try resource.update(.main, with: 1)
        try resource.mergeFromMain(into: fork)
        #expect(try resource.repository.versions(storedIn: fork).count == 0)
        try resource.update(.main, with: 2)
        #expect(try resource.repository.versions(storedIn: fork).count == 1)
        try resource.update(fork, with: 3)
        #expect(try resource.repository.versions(storedIn: fork).count == 2)
    }
}

