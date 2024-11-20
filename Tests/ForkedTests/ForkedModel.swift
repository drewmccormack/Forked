import Foundation
import Testing
import Forked
import ForkedMerge
@testable import ForkedModel

@ForkedModel
private struct User {
    var name: String = ""
    var age: Int = 0
}

@ForkedModel
struct Note {
    @Backed(by: .register) var title: String = ""
    @Merged(using: .textMerge) var text: String = ""
}

struct ForkedModelSuite {
    
    @Test func testInitialCreation() {
        let user = User(name: "Alice", age: 30)
        #expect(user.name == "Alice")
        #expect(user.age == 30)
    }
    
    @Test func testMergeDefault() throws {
        let user1 = User(name: "Alice", age: 30)
        var user2 = user1
        user2.name = "Bob"
        let user3 = try user2.merged(withOlderConflicting: user1, commonAncestor: user1)
        #expect(user3.name == "Bob")
        #expect(user3.age == 30)
    }
    
    @Test func testConcurrentEditsToDefaultMergeRules() throws {
        let ancestor = User(name: "Alice", age: 30)
        var user1 = ancestor
        var user2 = ancestor
        user1.name = "Bob Alice"
        user2.name = "Alice Bob"
        let merged = try user2.merged(withOlderConflicting: user1, commonAncestor: ancestor)
        #expect(merged.name == "Alice Bob")
        #expect(merged.age == 30)
    }
    
    @Test func testConcurrentEditsToRegisterFavorsMostRecent() async throws {
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
    
    @Test func testConcurrentEditsToTextMergeMergesString() async throws {
        var ancestor = Note()
        ancestor.text = "Text"
        var note1 = ancestor
        var note2 = ancestor
        note2.text = "More Text"
        note1.text = "Text More"
        let merged = try note2.merged(withOlderConflicting: note1, commonAncestor: ancestor)
        #expect(merged.text == "More Text More")
    }
    
}
