import Testing
@testable import Forked

struct MergingMergeablesSuite {
    let resource = QuickFork<AccumulatingInt>(initialValue: .init(), forkNames: ["fork"])
    let fork = Fork(name: "fork")
    
    @Test func syncAllForks() throws {
        try resource.update(fork, with: .init(value: 2))
        try resource.update(.main, with: .init(value: 3))
        try resource.syncAllForks()
        #expect(try resource.resource(of: fork)!.value == 5)
        #expect(try resource.resource(of: .main)!.value == 5)
        try resource.update(fork, with: .init(value: 7))
        try resource.update(.main, with: .init(value: 8))
        try resource.syncAllForks()
        #expect(try resource.resource(of: fork)!.value == 10)
        #expect(try resource.resource(of: .main)!.value == 10)
    }
    
    @Test func mergeIntoFork() throws {
        try resource.update(fork, with: .init(value: 2))
        try resource.update(.main, with: .init(value: 3))
        try resource.mergeAllForks(into: fork)
        #expect(try resource.resource(of: fork)!.value == 5)
        #expect(try resource.resource(of: .main)!.value == 3)
    }
    
    @Test func syncFork() throws {
        try resource.update(fork, with: .init(value: 2))
        try resource.update(.main, with: .init(value: 3))
        try resource.syncMain(with: [fork])
        #expect(try resource.resource(of: fork)!.value == 5)
        #expect(try resource.resource(of: .main)!.value == 5)
    }
}
