import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(ForkedModelMacros)
import ForkedModelMacros

final class ForkedModelMacrosSuite: XCTestCase {

    static let testMacros: [String: Macro.Type] = [
        "ForkedModel": ForkedModelMacro.self,
        "ForkedProperty": ForkedPropertyMacro.self,
    ]
    
    func testDefault() {
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

            extension TestModel: ForkedModel.Mergable {
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
    
    func testArrayPropertyMerge() {
        assertMacroExpansion(
            """
            @ForkedModel
            struct TestModel {
                @ForkedProperty(mergeWith: .array) var text: [String.Element]
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var text: [String.Element]
            }

            extension TestModel: ForkedModel.Mergable {
                public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
                    var merged = self
                    do {
                let merger = ValueArrayMerger<String.Element>()
                merged.text = try merger.merge(self.text, withOlderConflicting: other.text, commonAncestor: commonAncestor?.text)
                    }
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
    
    func testStringPropertyMerge() {
        assertMacroExpansion(
            """
            @ForkedModel
            struct TestModel {
                @ForkedProperty(mergeWith: .string) var text: String
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var text: String
            }

            extension TestModel: ForkedModel.Mergable {
                public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
                    var merged = self
                    do {
                let merger = StringMerger()
                merged.text = try merger.merge(self.text, withOlderConflicting: other.text, commonAncestor: commonAncestor?.text)
                    }
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
    
    func testMostRecentWinsPropertyMerge() {
        assertMacroExpansion(
            """
            @ForkedModel
            struct TestModel {
                @ForkedProperty(mergeWith: .mostRecent) var text: String
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var text: String {
                    get {
                        return _text.value
                    }
                    set {
                        _text.value = newValue
                    }
                }

                private var _text = Register<String>()
            }

            extension TestModel: ForkedModel.Mergable {
                public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
                    var merged = self
                    merged._text = self._text.merged(withOlderConflicting: other._text, commonAncestor: commonAncestor?._text)
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
}
#endif
