import Testing
@testable import Forked

struct StressSuite {
    
    @Test func complexUpdating() async throws {
        var result: Int = 0
        let resource = QuickFork<AccumulatingInt>(initialValue: .init(), forkNames: ["branch1", "branch2", "branch3"])
        try resource.update(.init(name: "branch1"), with: .init(value: 5))
        try resource.mergeIntoMain(from: .init(name: "branch1"))
        try resource.update(.init(name: "branch1"), with: .init(value: 4))
        try resource.syncMain(with: [.init(name: "branch1")])
        #expect(try resource.value(in: .main)?.value == 4)
        
        try resource.syncAllForks()
        #expect(try resource.value(in: .main)?.value == 4)
        
        try resource.update(.init(name: "branch2"), with: .init(value: 5))
        try resource.update(.init(name: "branch2"), with: .init(value: 6))
        try resource.update(.init(name: "branch1"), with: .init(value: 5))
        try resource.update(.init(name: "branch2"), with: .init(value: 7))
        try resource.update(.init(name: "branch2"), with: .init(value: 8))
        try resource.update(.init(name: "branch3"), with: .init(value: 5))
        try resource.update(.init(name: "branch2"), with: .init(value: 9))
        try resource.update(.init(name: "branch1"), with: .init(value: 6))
        try resource.update(.init(name: "branch2"), with: .init(value: 10))
        try resource.update(.init(name: "branch1"), with: .init(value: 7))
        try resource.update(.init(name: "branch1"), with: .init(value: 8))
        try resource.update(.init(name: "branch3"), with: .init(value: 6))
        try resource.update(.init(name: "branch3"), with: .init(value: 7))
        try resource.update(.init(name: "branch3"), with: .init(value: 8))
        try resource.update(.init(name: "branch3"), with: .init(value: 9))
        try resource.update(.init(name: "branch3"), with: .init(value: 10))
        try resource.update(.init(name: "branch1"), with: .init(value: 9))
        try resource.update(.init(name: "branch1"), with: .init(value: 10))
        try resource.syncAllForks()
        result = try resource.value(in: .main)!.value
        #expect(result == 22)
    }
    
    @Test func complexMerging() async throws {
        var result: Int = 0
        let resource = QuickFork<AccumulatingInt>(initialValue: .init(4), forkNames: ["branch1", "branch2", "branch3"])
        try resource.update(.init(name: "branch2"), with: .init(value: 5))
        try resource.mergeIntoMain(from: .init(name: "branch1"))
        try resource.update(.init(name: "branch2"), with: .init(value: 6))
        try resource.update(.init(name: "branch1"), with: .init(value: 5))
        try resource.mergeIntoMain(from: .init(name: "branch2"))
        try resource.update(.init(name: "branch2"), with: .init(value: 7))
        try resource.update(.init(name: "branch2"), with: .init(value: 8))
        try resource.update(.init(name: "branch3"), with: .init(value: 5))
        try resource.update(.init(name: "branch2"), with: .init(value: 9))
        try resource.mergeIntoMain(from: .init(name: "branch2"))
        try resource.update(.init(name: "branch1"), with: .init(value: 6))
        try resource.mergeIntoMain(from: .init(name: "branch1"))
        try resource.syncAllForks()
        result = try resource.value(in: .main)!.value
        #expect(result == 12)
        
        try resource.update(.init(name: "branch2"), with: .init(value: 10))
        try resource.update(.init(name: "branch1"), with: .init(value: 7))
        try resource.update(.init(name: "branch1"), with: .init(value: 8))
        try resource.mergeIntoMain(from: .init(name: "branch1"))
        try resource.update(.init(name: "branch3"), with: .init(value: 6))
        try resource.mergeIntoMain(from: .init(name: "branch2"))
        try resource.update(.init(name: "branch3"), with: .init(value: 7))
        try resource.syncAllForks()
        result = try resource.value(in: .main)!.value
        #expect(result == 1)
        
        try resource.update(.init(name: "branch3"), with: .init(value: 8))
        try resource.update(.init(name: "branch3"), with: .init(value: 9))
        try resource.mergeIntoMain(from: .init(name: "branch2"))
        try resource.update(.init(name: "branch3"), with: .init(value: 10))
        try resource.update(.init(name: "branch1"), with: .init(value: 9))
        try resource.mergeIntoMain(from: .init(name: "branch1"))
        try resource.update(.init(name: "branch1"), with: .init(value: 10))
        try resource.syncAllForks()
        
        result = try resource.value(in: .main)!.value
        #expect(result == 19)
    }
}
