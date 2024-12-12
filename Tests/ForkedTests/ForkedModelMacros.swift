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
        "Merged": MergeablePropertyMacro.self,
        "Backed": BackedPropertyMacro.self,
    ]
    
    func testDefault() {
        assertMacroExpansion(
            """
            @ForkedModel
            struct TestModel {
                @Merged var text: Elephant = ""
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var text: Elephant = ""
            }

            extension TestModel: Forked.Mergeable {
                public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                    var merged = self
                    merged.text = try self.text.merged(withSubordinate: other.text, commonAncestor: commonAncestor.text)
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
    
    func testTextDefault() {
        assertMacroExpansion(
            """
            @ForkedModel
            struct TestModel {
                @Merged var text: String = ""
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var text: String = ""
            }

            extension TestModel: Forked.Mergeable {
                public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                    var merged = self
                    merged.text = try merge(withMergerType: TextMerger.self, dominant: self.text, subordinate: other.text, commonAncestor: commonAncestor.text)
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
                @Merged(using: .arrayMerge) var text: [String.Element] = []
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var text: [String.Element] = []
            }

            extension TestModel: Forked.Mergeable {
                public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                    var merged = self
                    merged.text = try merge(withMergerType: ArrayMerger.self, dominant: self.text, subordinate: other.text, commonAncestor: commonAncestor.text)
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
    
    func testDefaultPropertyMergeOfArray() {
        assertMacroExpansion(
            """
            @ForkedModel
            struct TestModel {
                @Merged var text: [String.Element] = []
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var text: [String.Element] = []
            }

            extension TestModel: Forked.Mergeable {
                public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                    var merged = self
                    merged.text = try merge(withMergerType: ArrayMerger.self, dominant: self.text, subordinate: other.text, commonAncestor: commonAncestor.text)
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
    
    func testArrayOfIdentifiablePropertyMerge() {
        assertMacroExpansion(
            """
            @ForkedModel
            struct TestModel {
                @Merged(using: .arrayOfIdentifiableMerge) var text: [String.Element] = []
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var text: [String.Element] = []
            }

            extension TestModel: Forked.Mergeable {
                public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                    var merged = self
                    merged.text = try merge(withMergerType: ArrayOfIdentifiableMerger.self, dominant: self.text, subordinate: other.text, commonAncestor: commonAncestor.text)
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
    
    func testSetPropertyMerge() {
        assertMacroExpansion(
            """
            @ForkedModel
            struct TestModel {
                @Merged(using: .setMerge) var ints: Set<Int> = []
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var ints: Set<Int> = []
            }

            extension TestModel: Forked.Mergeable {
                public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                    var merged = self
                    merged.ints = try merge(withMergerType: SetMerger.self, dominant: self.ints, subordinate: other.ints, commonAncestor: commonAncestor.ints)
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
    
    func testDictionaryPropertyMerge() {
        assertMacroExpansion(
            """
            @ForkedModel
            struct TestModel {
                @Merged(using: .dictionaryMerge) var ints: Dictionary<String, Int> = [:]
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var ints: Dictionary<String, Int> = [:]
            }

            extension TestModel: Forked.Mergeable {
                public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                    var merged = self
                    merged.ints = try merge(withMergerType: DictionaryMerger.self, dominant: self.ints, subordinate: other.ints, commonAncestor: commonAncestor.ints)
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
                @Merged(using: .textMerge) var text: String = ""
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var text: String = ""
            }

            extension TestModel: Forked.Mergeable {
                public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                    var merged = self
                    merged.text = try merge(withMergerType: TextMerger.self, dominant: self.text, subordinate: other.text, commonAncestor: commonAncestor.text)
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
                @Backed var text: String = ""
                @Backed(by: .mergeableArray) var ints: [Int] = [1,2,3]
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var text: String = "" {
                    get {
                        return _text.value
                    }
                    set {
                        _text.value = newValue
                    }
                }

                public var _text = ForkedMerge.MergeableValue<String>("")
                var ints: [Int] = [1,2,3] {
                    get {
                        return _ints.values
                    }
                    set {
                        _ints.values = newValue
                    }
                }

                public var _ints = ForkedMerge.MergeableArray<Int>([1, 2, 3])
            }

            extension TestModel: Forked.Mergeable {
                public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                    var merged = self
                    merged._text = try self._text.merged(withSubordinate: other._text, commonAncestor: commonAncestor._text)
                    merged._ints = try self._ints.merged(withSubordinate: other._ints, commonAncestor: commonAncestor._ints)
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
    
    func testBackedAndMergedTogether() {
        assertMacroExpansion(
            """
            @ForkedModel
            private struct User {
                var name: String = ""
                var age: Int = 0
            }
            
            @ForkedModel
            private struct Note {
                @Backed(by: .mergeableValue) var title: String = ""
                @Merged(using: .textMerge) var text: String = ""
            }
            """,
            expandedSource:
            """
            private struct User {
                var name: String = ""
                var age: Int = 0
            }
            private struct Note {
                var title: String = "" {
                    get {
                        return _title.value
                    }
                    set {
                        _title.value = newValue
                    }
                }

                public var _title = ForkedMerge.MergeableValue<String>("")
                var text: String = ""
            }

            extension User: Forked.Mergeable {
                public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                    var merged = self
                    if areEqualForForked(self.name, commonAncestor.name) {
                merged.name = other.name
                    } else {
                merged.name = self.name
                    }
                    if areEqualForForked(self.age, commonAncestor.age) {
                        merged.age = other.age
                    } else {
                        merged.age = self.age
                    }
                    return merged
                }
            }

            extension Note: Forked.Mergeable {
                public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                    var merged = self
                    merged.text = try merge(withMergerType: TextMerger.self, dominant: self.text, subordinate: other.text, commonAncestor: commonAncestor.text)
                    merged._title = try self._title.merged(withSubordinate: other._title, commonAncestor: commonAncestor._title)
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
    
    func testOptionalMerged() {
        assertMacroExpansion(
            """
            @ForkedModel
            private struct Note {
                @Merged(using: .arrayMerge) var text: [String]?
            }
            """,
            expandedSource:
            """
            private struct Note {
                var text: [String]?
            }

            extension Note: Forked.Mergeable {
                public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                    var merged = self
                    merged.text = try merge(withMergerType: ArrayMerger.self, dominant: self.text, subordinate: other.text, commonAncestor: commonAncestor.text)
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
}
#endif

