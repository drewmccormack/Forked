import SwiftSyntax
import SwiftSyntaxMacros
import ForkedMerge

public struct BackedPropertyMacro: PeerMacro, AccessorMacro {
    
    public static let backingPropertyPrefix = "_forked_backedproperty_"
    
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
            throw ForkedModelError.appliedToNonVariable
        }
        
        guard let backing = try variableDecl.propertyBacking() else { return [] }
        
        let binding = variableDecl.bindings.first!
        let propertyName = binding.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
        let originalType = binding.typeAnnotation!.type.trimmedDescription
        let defaultValue = binding.initializer?.value.trimmedDescription ?? "nil"
        
        let backingProperty: DeclSyntax
        switch backing {
        case .register:
            backingProperty =
                """
                private var \(raw: backingPropertyPrefix + propertyName) = ForkedMerge.Register<\(raw: originalType)>(\(raw: defaultValue))
                """
        case .valueArray:
            guard originalType.hasPrefix("[") && originalType.hasSuffix("]") else {
                throw ForkedModelError.propertyBackingAndTypeAreIncompatible
            }
            let elementType = originalType.dropFirst().dropLast()
            backingProperty =
                """
                private var \(raw: backingPropertyPrefix + propertyName) = ForkedMerge.ValueArray<\(raw: elementType)>(\(raw: defaultValue))
                """
        }
        
        return [backingProperty]
    }
    
    public static func expansion(of node: AttributeSyntax, providingAccessorsOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
        guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
            throw ForkedModelError.appliedToNonVariable
        }
        
        guard let backing = try variableDecl.propertyBacking() else {
            throw ForkedModelError.propertyBackingAndTypeAreIncompatible
        }
        
        let propertyName = variableDecl.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
        let backingPropertyName = backingPropertyPrefix + propertyName

        let getter: String, setter: String
        switch backing {
        case .register:
            getter =
                """
                get {
                    return \(backingPropertyName).value
                }
                """
            setter =
                """
                set {
                    \(backingPropertyName).value = newValue
                }
                """
        case .valueArray:
            getter =
                """
                get {
                    return \(backingPropertyName).values
                }
                """
            setter =
                """
                set {
                    for diff in newValue.difference(from: \(backingPropertyName).values) {
                        switch diff {
                        case let .insert(offset, element, _):
                            \(backingPropertyName).insert(element, at: offset)
                        case let .remove(offset, _, _):
                            \(backingPropertyName).remove(at: offset)
                        }
                    }
                }
                """
        }
        
        return [
            AccessorDeclSyntax(stringLiteral: getter),
            AccessorDeclSyntax(stringLiteral: setter)
        ]
    }
    
}
