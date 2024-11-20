import Foundation
import Testing
@testable import Forked

struct RepositoriesSuite {
    
    @Test func savingBasicAtomicRepository() throws {
        let repo = AtomicRepository<Int>()
        let _ = try ForkedResource(repository: repo)
        let data = try JSONEncoder().encode(repo)
        let newRepo = try JSONDecoder().decode(AtomicRepository<Int>.self, from: data)
        let newResource = try ForkedResource(repository: newRepo)
        #expect(newResource.forks == [.main])
        #expect(try newResource.mostRecentVersionOfMain().count == 0)
    }
    
    @Test func savingAtomicRepositoryWithChanges() throws {
        let repo = AtomicRepository<Int>()
        let resource = try ForkedResource(repository: repo)
        let fork = Fork(name: "fork")
        try resource.create(fork)
        try resource.update(fork, with: 2)
        try resource.update(fork, with: 3)
        try resource.update(.main, with: 4)
        let data = try JSONEncoder().encode(repo)
        let newRepo = try JSONDecoder().decode(AtomicRepository<Int>.self, from: data)
        let newResource = try ForkedResource(repository: newRepo)
        #expect(newResource.forks.count == 2)
        #expect(try newResource.mostRecentVersion(of: fork).count == 2)
        #expect(try newResource.resource(of: fork) == 3)
        #expect(try newRepo.versions(storedIn: fork).count == 2)
        #expect(try newResource.mostRecentVersionOfMain().count == 3)
        #expect(try newResource.resource(of: .main) == 4)
    }
    
}
