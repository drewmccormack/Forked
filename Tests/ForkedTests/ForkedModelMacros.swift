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
        "Merged": MergablePropertyMacro.self,
        "Backed": BackedPropertyMacro.self,
    ]
    
    func testDefault() {
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

            extension TestModel: ForkedModel.Mergable {
                public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
                    var merged = self
                    merged.text = try self.text.merged(withOlderConflicting: other.text, commonAncestor: commonAncestor?.text)
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
                @Merged(using: .textMerge) var text: String = ""
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var text: String = ""
            }

            extension TestModel: ForkedModel.Mergable {
                public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
                    var merged = self
                    do {
                let merger = TextMerger()
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
                @Backed var text: String = ""
                @Backed(by: .valueArray) var ints: [Int] = [1,2,3]
            }
            """,
            expandedSource:
            """
            struct TestModel {
                var text: String = "" {
                    get {
                        return _forked_backedproperty_text.value
                    }
                    set {
                        _forked_backedproperty_text.value = newValue
                    }
                }

                private var _forked_backedproperty_text = ForkedMerge.Register<String>("")
                var ints: [Int] = [1,2,3] {
                    get {
                        return _forked_backedproperty_ints.values
                    }
                    set {
                        for diff in newValue.difference(from: _forked_backedproperty_ints.values) {
                            switch diff {
                            case let .insert(offset, element, _):
                                _forked_backedproperty_ints.insert(element, at: offset)
                            case let .remove(offset, _, _):
                                _forked_backedproperty_ints.remove(at: offset)
                            }
                        }
                    }
                }

                private var _forked_backedproperty_ints = ForkedMerge.ValueArray<Int>([1, 2, 3])
            }

            extension TestModel: ForkedModel.Mergable {
                public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
                    var merged = self
                    merged._forked_backedproperty_text = try self._forked_backedproperty_text.merged(withOlderConflicting: other._forked_backedproperty_text, commonAncestor: commonAncestor?._forked_backedproperty_text)
                    merged._forked_backedproperty_ints = try self._forked_backedproperty_ints.merged(withOlderConflicting: other._forked_backedproperty_ints, commonAncestor: commonAncestor?._forked_backedproperty_ints)
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
                @Backed(by: .register) var title: String = ""
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
                        return _forked_backedproperty_title.value
                    }
                    set {
                        _forked_backedproperty_title.value = newValue
                    }
                }

                private var _forked_backedproperty_title = ForkedMerge.Register<String>("")
                var text: String = ""
            }

            extension User: ForkedModel.Mergable {
                public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
                    var merged = self
                    if  let anyEquatableSelf = ForkedEquatable(self.name),
                case let anyEquatableCommon = commonAncestor.flatMap({
                            ForkedEquatable($0.name)
                        }) {
                merged.name = anyEquatableSelf != anyEquatableCommon ? self.name : other.name
                    }
                    if  let anyEquatableSelf = ForkedEquatable(self.age),
                        case let anyEquatableCommon = commonAncestor.flatMap({
                            ForkedEquatable($0.age)
                        }) {
                        merged.age = anyEquatableSelf != anyEquatableCommon ? self.age : other.age
                    }
                    return merged
                }
            }

            extension Note: ForkedModel.Mergable {
                public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
                    var merged = self
                    do {
                let merger = TextMerger()
                merged.text = try merger.merge(self.text, withOlderConflicting: other.text, commonAncestor: commonAncestor?.text)
                    }
                    merged._forked_backedproperty_title = try self._forked_backedproperty_title.merged(withOlderConflicting: other._forked_backedproperty_title, commonAncestor: commonAncestor?._forked_backedproperty_title)
                    return merged
                }
            }
            """,
            macros: Self.testMacros
        )
    }
}
#endif

