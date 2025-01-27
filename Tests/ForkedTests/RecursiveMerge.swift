import Testing
import Foundation
import Forked
@testable import ForkedMerge
@testable import ForkedModel


@ForkedModel(version: 0)
struct Status: Codable, Hashable, Identifiable {
    var id = UUID()
    var status: String = ""
    var note: String = ""

    init(status: String = "Absent", note: String = "") {
        self.status = status
        self.note = note
    }
}

@ForkedModel(version: 0)
struct StatusesForDate: Codable, Hashable {
    var date: Date = .now
    @Merged(using: .arrayOfIdentifiableMerge) var statuses: [Status] = []
    @Merged(using: .dictionaryMerge) var keysToStatuses: [String:Status] = [:]
}

final class Store {
    typealias RepoType = AtomicRepository<StatusesForDate>
    let repo: RepoType
    let forkedModel: ForkedResource<RepoType>

    init() throws {
        repo = AtomicRepository()
        forkedModel = try ForkedResource(repository: repo)
    }
}


struct RecursiveMergeSuite {

    @Test func mergeRecursively() throws {
        let store = try Store()
        let model = store.forkedModel

        var data = StatusesForDate()
        for i in 0..<3 {
            data.statuses.append(Status())
            data.keysToStatuses["\(i)"] = Status()
        }
        try model.update(.main, with: data)

        let f1 = Fork(name: "f1")
        try model.create(f1)

        let f2 = Fork(name: "f2")
        try model.create(f2)

        try model.syncAllForks()

        for f in [.main, f1, f2] {
            let r = try model.resource(of: f)!
            #expect(r.statuses.map(\.status) == ["Absent", "Absent", "Absent"])
            #expect(r.statuses.map(\.note) == ["", "", ""])
            #expect(Set(r.statuses.map(\.id)).count == 3)
            #expect(["0","1","2"].map({ r.keysToStatuses[$0]!.status }) == ["Absent", "Absent", "Absent"])
            #expect(["0","1","2"].map({ r.keysToStatuses[$0]!.note }) == ["", "", ""])
        }

        var f1Data = try model.resource(of: f1)!
        f1Data.statuses[1].status  = "Present"
        f1Data.keysToStatuses["1"]!.status = "Present"
        f1Data.statuses[2].note = "2"
        f1Data.keysToStatuses["2"]!.note = "2"
        try model.update(f1, with: f1Data)
        #expect(f1Data.statuses.map(\.status) == ["Absent", "Present", "Absent"])
        #expect(["0","1","2"].map({ f1Data.keysToStatuses[$0]!.status }) == ["Absent", "Present", "Absent"])
        #expect(f1Data.statuses.map(\.note) == ["", "", "2"])

        try model.mergeIntoMain(from: f1)
        
        var mainData = try model.resource(of: .main)!
        #expect(mainData.statuses.count == 3)
        #expect(mainData.statuses.map(\.status) == ["Absent", "Present", "Absent"])
        #expect(["0","1","2"].map({ mainData.keysToStatuses[$0]!.status }) == ["Absent", "Present", "Absent"])
        #expect(mainData.statuses.map(\.note) == ["", "", "2"])

        var f2Data = try model.resource(of: f2)!
        f2Data.statuses[2].status  = "Late"
        f2Data.keysToStatuses["2"]!.status = "Late"
        f2Data.statuses[1].note = "1"
        f2Data.keysToStatuses["1"]!.note = "1"
        try model.update(f2, with: f2Data)
        #expect(f2Data.statuses.map(\.note) == ["", "1", ""])
        #expect(f2Data.statuses.map(\.status) == ["Absent", "Absent", "Late"])
        #expect(["0","1","2"].map({ f2Data.keysToStatuses[$0]!.status }) == ["Absent", "Absent", "Late"])

        let action = try model.mergeIntoMain(from: f2)
        #expect(action == .resolveConflict)

        mainData = try model.resource(of: .main)!
        #expect(mainData.statuses.map(\.status) == ["Absent", "Present", "Late"])
        #expect(mainData.keysToStatuses["0"]!.status == "Absent")
        #expect(mainData.keysToStatuses["1"]!.status == "Present")
        #expect(mainData.keysToStatuses["2"]!.status == "Late")
        #expect(mainData.statuses.map(\.note) == ["", "1", "2"])
        #expect(mainData.keysToStatuses["0"]!.note == "")
        #expect(mainData.keysToStatuses["1"]!.note == "1")
        #expect(mainData.keysToStatuses["2"]!.note == "2")
    }
}
