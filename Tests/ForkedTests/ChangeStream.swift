import Testing
@testable import Forked

struct ChangeStreamSuite {
    
    typealias Repo = AtomicRepository<Int>
    let repo = try! AtomicRepository<Int>()
    let resource: ForkedResource<Repo>
    let fork = Fork(name: "fork")
    let stream: ChangeStream
    var iterator: ChangeStream.Iterator

    init() throws {
        resource = try ForkedResource(repository: repo)
        try resource.create(fork)
        stream = resource.changeStream
        iterator = stream.makeAsyncIterator()
    }
    
    @Test mutating func singleChangeTriggersSingleValueInStream() async throws {
        try resource.update(.main, with: 1)
        let change = await iterator.next()
        #expect(change?.fork == .main)
        #expect(change?.version.count == 1)
        #expect(change?.mergingFork == nil)
    }
    
    @Test mutating func doubleChangeTriggersTwoValuesInStream() async throws {
        try resource.update(.main, with: 1)
        try resource.update(.main, with: 2)
        let change1 = await iterator.next()
        let change2 = await iterator.next()
        #expect(change1?.fork == .main)
        #expect(change1?.version.count == 1)
        #expect(change1?.mergingFork == nil)
        #expect(change2?.fork == .main)
        #expect(change2?.version.count == 2)
        #expect(change2?.mergingFork == nil)
    }
    
    @Test func releasingStreamRemovesContinuation() async throws {
        let repo = try AtomicRepository<Int>()
        let resource = try ForkedResource(repository: repo)
        do {
            let stream = resource.changeStream
            var iterator = stream.makeAsyncIterator()
            try resource.update(.main, with: 1)
            try resource.update(.main, with: 2)
            let _ = await iterator.next()
            let _ = await iterator.next()
            #expect(resource.hasSubscribedChangeStreams)
        }
        #expect(!resource.hasSubscribedChangeStreams)
    }
    
    @Test mutating func changeStreamDoesNotContainMergingFork() async throws {
        try resource.update(.main, with: 1)
        let change = await iterator.next()
        #expect(change?.mergingFork == nil)
    }
    
    @Test mutating func changeStreamContainsMergingFork() async throws {
        try resource.update(fork, with: 1)
        try resource.mergeIntoMain(from: fork)
        let updateChange = await iterator.next()
        let mergeChange = await iterator.next()
        #expect(updateChange?.mergingFork == nil)
        #expect(mergeChange?.mergingFork == fork)
    }
}
