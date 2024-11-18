import SwiftSyntax
import SwiftSyntaxMacros

/// The algorithm used to merge changes to a property.
/// Some properties know how to merge themselves; they conform to `Mergable`.
/// Other types have no intrinsic merge, but can be merged by a `Merger`.
public enum MergeAlgorithm: String {
    /// The property must be a `Mergable` type, and will be merged accordingly
    /// to the `Mergable` protocol.
    /// This is the default algorithm for `@ForkedProperty`.
    case property
    
    /// Will merge as an array of values. When there is a conflict, it will
    /// determine the changes made to each version, and merge on that basis.
    /// Does not guarantee uniqueness of elements after merge.
    /// There can be duplicates created, so it is more suitable to value types
    /// like characters in a string. than it is to identifiable types.
    case array
    
    /// Applies the array merge to the characters in a string.
    /// The variable must be a `String`.
    case string
}

public struct ForkedPropertyMacro: AccessorMacro {
    public static func expansion(of node: AttributeSyntax, providingAccessorsOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
        guard let _ = declaration.as(VariableDeclSyntax.self) else {
            throw ForkedModelError.appliedToNonVariable
        }
        return []
    }
}
