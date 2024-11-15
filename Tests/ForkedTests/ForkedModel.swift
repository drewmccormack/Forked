import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(ForkedModelMacros)
import ForkedModelMacros

final class ForkedModelSuite: XCTestCase {

    static let testMacros: [String: Macro.Type] = [
        "ForkedModel": ForkedModelMacro.self,
        "ForkedProperty": ForkedPropertyMacro.self,
    ]
    
    func testMacro() throws {
        assertMacroExpansion(
            """
            @ForkedModel
            struct TestModel {
                @ForkedProperty var text: String
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var text: String
            }

            extension TestModel: Forked.Mergable {
                public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
                    var merged = self
                    merged.text = self.text.merged(withOlderConflicting: other.text, commonAncestor: commonAncestor?.text)
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
    
}
#endif
