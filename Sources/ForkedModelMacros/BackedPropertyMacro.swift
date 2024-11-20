import SwiftSyntax
import SwiftSyntaxMacros
import ForkedMerge

public struct BackedPropertyMacro: PeerMacro, AccessorMacro {
    
    public static let backingPropertyPrefix = "_forked_backedproperty_"
    
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
            throw ForkedModelError.appliedToNonVariable
        }
        
        guard let _ = try variableDecl.propertyBacking() else { return [] }
        
        let propertyName = variableDecl.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
        let originalType = variableDecl.bindings.first!.typeAnnotation!.type.trimmedDescription
        let backingProperty: DeclSyntax =
            """
            private var \(raw: backingPropertyPrefix + propertyName) = Register<\(raw: originalType)>(.init())
            """
        
        return [backingProperty]
    }
    
    public static func expansion(of node: AttributeSyntax, providingAccessorsOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
        guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
            throw ForkedModelError.appliedToNonVariable
        }
        
        guard let _ = try variableDecl.propertyBacking() else {
            throw ForkedModelError.propertyBackingAndTypeAreIncompatible
        }
        
        let propertyName = variableDecl.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
        let getter =
            """
            get {
                return \(backingPropertyPrefix + propertyName).value
            }
            """
        let setter =
            """
            set {
                \(backingPropertyPrefix + propertyName).value = newValue
            }
            """
        
        return [
            AccessorDeclSyntax(stringLiteral: getter),
            AccessorDeclSyntax(stringLiteral: setter)
        ]
    }
    
}
