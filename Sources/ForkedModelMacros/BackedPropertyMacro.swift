import SwiftSyntax
import SwiftSyntaxMacros
import ForkedMerge

public struct BackedPropertyMacro: PeerMacro, AccessorMacro {
    
    public static let backingPropertyPrefix = "_"
    
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
        case .mergeableValue:
            backingProperty =
                """
                public var \(raw: backingPropertyPrefix + propertyName) = ForkedMerge.MergeableValue<\(raw: originalType)>(\(raw: defaultValue))
                """
        case .mergeableArray:
            guard originalType.hasPrefix("[") && originalType.hasSuffix("]") else {
                throw ForkedModelError.propertyBackingAndTypeAreIncompatible
            }
            let elementType = originalType.dropFirst().dropLast()
            backingProperty =
                """
                public var \(raw: backingPropertyPrefix + propertyName) = ForkedMerge.MergeableArray<\(raw: elementType)>(\(raw: defaultValue))
                """
        case .mergeableSet:
            guard originalType.hasPrefix("Set<") && originalType.hasSuffix(">") else {
                throw ForkedModelError.propertyBackingAndTypeAreIncompatible
            }
            let elementType = originalType.dropFirst(4).dropLast()
            backingProperty =
                """
                public var \(raw: backingPropertyPrefix + propertyName) = ForkedMerge.MergeableSet<\(raw: elementType)>(\(raw: defaultValue))
                """
        case .mergeableDictionary:
            guard let (keyType, valueType) = extractKeyAndValueTypes(from: originalType) else {
                throw ForkedModelError.propertyBackingAndTypeAreIncompatible
            }
            backingProperty =
                """
                public var \(raw: backingPropertyPrefix + propertyName) = ForkedMerge.MergeableDictionary<\(raw: keyType), \(raw: valueType)>(\(raw: defaultValue))
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
        case .mergeableValue:
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
        case .mergeableArray, .mergeableSet:
            getter =
                """
                get {
                    return \(backingPropertyName).values
                }
                """
            setter =
                """
                set {
                    \(backingPropertyName).values = newValue
                }
                """
        case .mergeableDictionary:
            getter =
                """
                get {
                    return \(backingPropertyName).dictionary
                }
                """
            setter =
                """
                set {
                    \(backingPropertyName).dictionary = newValue
                }
                """
        }
        
        return [
            AccessorDeclSyntax(stringLiteral: getter),
            AccessorDeclSyntax(stringLiteral: setter)
        ]
    }
    
}
