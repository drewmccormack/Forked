import Foundation
import Testing
import Forked
import ForkedMerge
@testable import ForkedModel

@ForkedModel
struct User: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String = ""
    var age: Int = 0
}

struct NoteItem: Equatable, Identifiable {
    var id: String
}

@ForkedModel
struct Note {
    @Backed(by: .mergeableValue) var title: String = ""
    @Backed(by: .mergeableArray) var pageWordCounts: [Int] = []
    @Backed(by: .mergeableSet) var tags: Set<String> = []
    @Backed(by: .mergeableDictionary) var counts: [String: Int] = [:]
    @Merged(using: .textMerge) var description: String = ""
    @Merged(using: .arrayMerge) var aliases: [String] = []
    @Merged(using: .arrayOfIdentifiableMerge) var items: [NoteItem] = []
    @Merged(using: .setMerge) var categories: Set<String> = []
    @Merged(using: .dictionaryMerge) var metadata: [String:String] = [:]
}

struct ForkedModelSuite {
    
    @Test func initialCreation() {
        let user = User(name: "Alice", age: 30)
        #expect(user.name == "Alice")
        #expect(user.age == 30)
    }
    
    @Test func mergeDefault() throws {
        let user1 = User(name: "Alice", age: 30)
        var user2 = user1
        user2.name = "Bob"
        let user3 = try user2.merged(withOlderConflicting: user1, commonAncestor: user1)
        #expect(user3.name == "Bob")
        #expect(user3.age == 30)
    }
    
    @Test func concurrentEditsToDefaultMergeRules() throws {
        let ancestor = User(name: "Alice", age: 30)
        var user1 = ancestor
        var user2 = ancestor
        user1.name = "Bob Alice"
        user2.name = "Alice Bob"
        let merged = try user2.merged(withOlderConflicting: user1, commonAncestor: ancestor)
        #expect(merged.name == "Alice Bob")
        #expect(merged.age == 30)
    }
    
    @Test func propertiesUsingDefaultMergeAreMergedIndependently() async throws {
        let ancestor = User(name: "Alice", age: 30)
        var user1 = ancestor
        var user2 = ancestor
        user1.name = "Bob Alice"
        user2.age = 40
        let merged = try user2.merged(withOlderConflicting: user1, commonAncestor: ancestor)
        #expect(merged.name == "Bob Alice")
        #expect(merged.age == 40)
    }
    
    @Test func defaultMergeFavorsMoreRecentWhenConflicting() async throws {
        let ancestor = User(name: "Alice", age: 30)
        var user1 = ancestor
        var user2 = ancestor
        user1.name = "Bob Alice"
        user2.name = "Tom"
        let merged = try user2.merged(withOlderConflicting: user1, commonAncestor: ancestor)
        #expect(merged.name == "Tom")
    }
    
    @Test func defaultMergeFavorsMoreRecentWhenNoCommonAncestor() async throws {
        let ancestor = User(name: "Alice", age: 30)
        var user1 = ancestor
        var user2 = ancestor
        user1.name = "Bob Alice"
        user2.name = "Tom"
        let merged = try user2.merged(withOlderConflicting: user1, commonAncestor: nil)
        #expect(merged.name == "Tom")
    }
    
    @Test func concurrentEditsToMergeableValueFavorsMostRecent() async throws {
        var ancestor = Note()
        ancestor.title = "Title 1"
        var note1 = ancestor
        var note2 = ancestor
        note2.title = "Title 3"
        try? await Task.sleep(for: .milliseconds(1))
        note1.title = "Title 2"
        let merged = try note2.merged(withOlderConflicting: note1, commonAncestor: ancestor)
        #expect(merged.title == "Title 2")
    }
    
    @Test func concurrentEditsToTextMergeMergesString() async throws {
        var ancestor = Note()
        ancestor.description = "Text"
        var note1 = ancestor
        var note2 = ancestor
        note2.description = "More Text"
        note1.description = "Text More"
        let merged = try note2.merged(withOlderConflicting: note1, commonAncestor: ancestor)
        #expect(merged.description == "More Text More")
    }

    @Test func mergeableArrayBacking() async throws {
        var ancestor = Note()
        ancestor.pageWordCounts = [1, 2, 3]
        var note1 = ancestor
        var note2 = ancestor
        note1.pageWordCounts = [1, 3, 4]
        note2.pageWordCounts = [1, 2, 3, 4]
        let merged = try note2.merged(withOlderConflicting: note1, commonAncestor: ancestor)
        #expect(merged.pageWordCounts == [1, 3, 4, 4])
    }
    
    @Test func arrayMerging() async throws {
        var ancestor = Note()
        ancestor.aliases = ["one", "two", "three"]
        var note1 = ancestor
        var note2 = ancestor
        note1.aliases = ["one"]
        note2.aliases = ["one", "four"]
        let merged = try note2.merged(withOlderConflicting: note1, commonAncestor: ancestor)
        #expect(merged.aliases == ["one", "four"])
    }
    
    @Test func arrayOfIdentifiableMerging() async throws {
        var ancestor = Note()
        ancestor.items = [NoteItem(id: "1"), NoteItem(id: "2")]
        var note1 = ancestor
        var note2 = ancestor
        note1.items = [NoteItem(id: "1"), NoteItem(id: "3")]
        note2.items = [NoteItem(id: "3"), NoteItem(id: "1")]
        let merged = try note2.merged(withOlderConflicting: note1, commonAncestor: ancestor)
        #expect(merged.items.map({ $0.id }) == ["3", "1"])
    }
    
    @Test func mergeableSetBacking() async throws {
        var ancestor = Note()
        ancestor.tags = ["Tag1", "Tag2", "Tag3"]
        var note1 = ancestor
        var note2 = ancestor
        note1.tags = ["Tag1", "Tag4"]
        note2.tags = ["Tag1", "Tag2", "Tag3", "Tag5"]
        let merged = try note2.merged(withOlderConflicting: note1, commonAncestor: ancestor)
        #expect(merged.tags == ["Tag1", "Tag4", "Tag5"])
    }
    
    @Test func setMerging() async throws {
        var ancestor = Note()
        ancestor.categories = ["A", "B", "C"]
        var note1 = ancestor
        var note2 = ancestor
        note1.categories = ["A", "D"]
        note2.categories = ["C", "E"]
        let merged = try note2.merged(withOlderConflicting: note1, commonAncestor: ancestor)
        #expect(merged.categories == ["D", "E"])
    }

    @Test func mergeableDictionaryBacked() async throws {
        var ancestor = Note()
        ancestor.counts = ["key1": 1, "key2": 2]
        var note1 = ancestor
        var note2 = ancestor
        note1.counts = ["key1": 1]
        note2.counts = ["key2": 5, "key3": 6]
        let merged = try note2.merged(withOlderConflicting: note1, commonAncestor: ancestor)
        #expect(merged.counts == ["key2": 5, "key3": 6])
    }
    
    @Test func dictionaryMerging() async throws {
        var ancestor = Note()
        ancestor.metadata = ["key1": "value1", "key2": "value2"]
        var note1 = ancestor
        var note2 = ancestor
        note1.metadata = ["key1": "value3"]
        note2.metadata = ["key2": "value4", "key3": "value5"]
        let merged = try note2.merged(withOlderConflicting: note1, commonAncestor: ancestor)
        #expect(merged.metadata == ["key2": "value4", "key3": "value5"])
    }
}
