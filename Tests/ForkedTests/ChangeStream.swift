import Testing
@testable import Forked

struct ChangeStreamSuite {
    
    @Test func singleChangeTriggersSingleValueInStream() async throws {
        let repo = AtomicRepository<Int>()
        let resource = try ForkedResource(repository: repo)
        let stream = resource.changeStream
        var iterator = stream.makeAsyncIterator()
        try resource.update(.main, with: 1)
        let change = await iterator.next()
        #expect(change?.fork == .main)
        #expect(change?.version.count == 1)
        #expect(change?.mergingFork == nil)
    }
    
    @Test func doubleChangeTriggersTwoValuesInStream() async throws {
        let repo = AtomicRepository<Int>()
        let resource = try ForkedResource(repository: repo)
        let stream = resource.changeStream
        var iterator = stream.makeAsyncIterator()
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
        let repo = AtomicRepository<Int>()
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
    
}
