import Foundation
import Testing
import Forked
@testable import ForkedModel

@ForkedModel
struct User {
    var name: String
    var age: Int
}

struct ForkedModelSuite {
    
    @Test func testInitialCreation() {
        let user = User(name: "Alice", age: 30)
        #expect(user.name == "Alice")
        #expect(user.age == 30)
    }
    
}
