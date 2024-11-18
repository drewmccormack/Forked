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
    
    /// This uses a `Register` type as the backing of the variable.
    /// The register stores a timestamp with the value whenever there is an update.
    /// A merge will choose the most recent updated value.
    case mostRecentWins
    
    var needsBackingType: Bool {
        switch self {
        case .mostRecentWins:
            return true
        case .property, .array, .string:
            return false
        }
    }
}

public struct ForkedPropertyMacro: PeerMacro, AccessorMacro {
    
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
            throw ForkedModelError.appliedToNonVariable
        }
        
        guard let alg = try variableDecl.mergeAlgorithm(), alg.needsBackingType else { return [] }
        
        let propertyName = variableDecl.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
        let originalType = variableDecl.bindings.first!.typeAnnotation!.type.trimmedDescription
        let backingProperty: DeclSyntax =
            """
            private var _\(raw: propertyName) = Register<\(raw: originalType)>()
            """
        
        return [backingProperty]
    }
    
    public static func expansion(of node: AttributeSyntax, providingAccessorsOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
        guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
            throw ForkedModelError.appliedToNonVariable
        }
        
        guard let alg = try variableDecl.mergeAlgorithm(), alg.needsBackingType else { return [] }
        
        let propertyName = variableDecl.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
        let getter =
            """
            get {
                return _\(propertyName).value
            }
            """
        let setter =
            """
            set {
                _\(propertyName).value = newValue
            }
            """
        
        return [
            AccessorDeclSyntax(stringLiteral: getter),
            AccessorDeclSyntax(stringLiteral: setter)
        ]
    }
    
}
