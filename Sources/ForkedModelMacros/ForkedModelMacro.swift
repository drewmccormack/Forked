import SwiftSyntax
import SwiftSyntaxMacros

// Define our own local version of PropertyMerge to avoid ForkedMerge dependency
public enum PropertyMerge: String {
    case mergeableProtocol
    case arrayMerge
    case arrayOfIdentifiableMerge
    case setMerge
    case dictionaryMerge
    case textMerge
}

// Define our own local version of PropertyBacking to avoid ForkedMerge dependency
public enum PropertyBacking: String {
    case mergeableValue
    case mergeableArray
    case mergeableSet
    case mergeableDictionary
}

enum PropertyVariety {
    case singleValue
    case array
    case dictionary
    case set
    case text
    
    var defaultPropertyMerge: PropertyMerge {
        let defaultMerge: PropertyMerge
        switch self {
        case .singleValue:
            defaultMerge = .mergeableProtocol
        case .array:
            defaultMerge = .arrayMerge
        case .dictionary:
            defaultMerge = .dictionaryMerge
        case .set:
            defaultMerge = .setMerge
        case .text:
            defaultMerge = .textMerge
        }
        return defaultMerge
    }
}

private struct MergePropertyVar {
    var varSyntax: VariableDeclSyntax
    var merge: PropertyMerge?
    var propertyVariety: PropertyVariety
}

private struct BackedPropertyVar {
    var varSyntax: VariableDeclSyntax
    var backing: PropertyBacking
}

private let versionLabel = "version"

public struct ForkedModelMacro: ExtensionMacro, MemberMacro {
    // Helper function to extract key and value types from Dictionary type
    public static func extractKeyAndValueTypes(from type: String) -> (String, String)? {
        // We have a few ways to represent dictionaries
        if type.hasPrefix("[") && type.contains(":") && type.hasSuffix("]") {
            // [Key: Value]
            let content = type.dropFirst().dropLast()
            guard let colonIndex = content.firstIndex(of: ":") else { return nil }
            let key = String(content[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(content[content.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            return (key, value)
        } else if type.hasPrefix("Dictionary<") && type.hasSuffix(">") {
            // Dictionary<Key, Value>
            let content = type.dropFirst(11).dropLast()
            guard let commaIndex = content.firstIndex(of: ",") else { return nil }
            let key = String(content[..<commaIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(content[content.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces)
            return (key, value)
        }
        return nil
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        if let version = extractVersion(from: node) {
            // Check if struct conforms to VersionedModel
            if let structDecl = declaration.as(StructDeclSyntax.self) {
                let conformsToVersionedModel = structDecl.inheritanceClause?.inheritedTypes.contains {
                    $0.type.trimmedDescription == "VersionedModel"
                } ?? false
                
                if conformsToVersionedModel {
                    throw ForkedModelError.conformsToVersionedModel
                }
            }
            
            return [
                """
                public static let currentModelVersion: Int = \(raw: version)
                public var modelVersion: Int? = Self.currentModelVersion
                """
            ]
        }
        
        return []
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {        
        // Check that the node is a struct
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw ForkedModelError.appliedToNonStruct
        }
        
        // Check if the struct already conforms to Mergeable
        let alreadyConformsToMergeable = structDecl.inheritanceClause?.inheritedTypes.contains {
            $0.type.trimmedDescription == "Mergeable" || $0.type.trimmedDescription == "Forked.Mergeable"
        } ?? false
        
        // If it already conforms to Mergeable, throw an error
        guard !alreadyConformsToMergeable else {
            throw ForkedModelError.conformsToMergeable
        }
        
        // Make sure the struct has defaults for all properties that are stored and non-optional
        guard structDecl.allStoredPropertiesHaveDefaultValue else {
            throw ForkedModelError.nonOptionalStoredPropertiesMustHaveDefaultValues
        }

        // Get all vars
        let allPropertyVars: [VariableDeclSyntax] = structDecl.memberBlock.members.compactMap { member -> VariableDeclSyntax? in
            guard let varSyntax = member.decl.as(VariableDeclSyntax.self) else { return nil }
            guard !varSyntax.isComputed() else { return nil }
            guard !varSyntax.isStatic() else { return nil }
            return varSyntax
        }
        
        // Gather names of all mergeable properties
        let mergePropertyVars: [MergePropertyVar] = try structDecl.memberBlock.members.compactMap { member -> MergePropertyVar? in
            guard let varSyntax = member.decl.as(VariableDeclSyntax.self), 
                  varSyntax.isMerged(), 
                  !varSyntax.isComputed(),
                  !varSyntax.isStatic()
                else { return nil }
            let propertyMerge = try varSyntax.propertyMerge()
            return MergePropertyVar(varSyntax: varSyntax, merge: propertyMerge, propertyVariety: varSyntax.propertyVariety())
        }
        
        // Gather names of all backed properties
        let backedPropertyVars: [BackedPropertyVar] = try structDecl.memberBlock.members.compactMap { member -> BackedPropertyVar? in
            guard let varSyntax = member.decl.as(VariableDeclSyntax.self),
                  let backing = try varSyntax.propertyBacking(),
                  !varSyntax.isComputed(),
                  !varSyntax.isStatic()
                else { return nil }
            return BackedPropertyVar(varSyntax: varSyntax, backing: backing)
        }
        
        // Variables that should use the default merge
        let defaultMergeVars = allPropertyVars.filter { varSyntax in
            !mergePropertyVars.contains { $0.varSyntax == varSyntax } &&
            !backedPropertyVars.contains { $0.varSyntax == varSyntax }
        }
        
        // Generate the Mergeable extension
        let mergeableExtension = try generateMergeableExtension(for: type, structDecl: structDecl, defaultMergeVars: defaultMergeVars, mergePropertyVars: mergePropertyVars, backedPropertyVars: backedPropertyVars)
        
        // If version is provided, also generate VersionedModel extension
        if extractVersion(from: node) != nil {
            let versionedModelExtension = try ExtensionDeclSyntax(
                """
                extension \(type.trimmed): Forked.VersionedModel {}
                """
            )
            return [mergeableExtension, versionedModelExtension]
        }
        
        return [mergeableExtension]
    }
    
    // Move the existing Mergeable extension generation to a helper method
    private static func generateMergeableExtension(
        for type: some TypeSyntaxProtocol,
        structDecl: StructDeclSyntax,
        defaultMergeVars: [VariableDeclSyntax],
        mergePropertyVars: [MergePropertyVar],
        backedPropertyVars: [BackedPropertyVar]
    ) throws -> ExtensionDeclSyntax {
        // Generate merge expression for defaults
        var expressions: [String] = []
        for varSyntax in defaultMergeVars {
            let varName = varSyntax.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
            let expr =
                """
                if self.\(varName) == commonAncestor.\(varName) {
                    merged.\(varName) = other.\(varName)
                } else {
                    merged.\(varName) = self.\(varName)
                }
                """
            expressions.append(expr)
        }
        
        // Generate merge expression for each variable
        for propertyInfo in mergePropertyVars {
            let varSyntax = propertyInfo.varSyntax
            let varName = varSyntax.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
            let varType = varSyntax.bindings.first!.typeAnnotation!.type.trimmedDescription
            let expr: String
            
            func mergeExpr(mergerSetup: String) -> String {
                """
                do {
                    \(mergerSetup)
                    merged.\(varName) = try merge(merger: merger, dominant: self.\(varName), subordinate: other.\(varName), commonAncestor: commonAncestor.\(varName))
                }
                """
            }
            
            // If no merge given, fall back on default for variety
            let defaultMerge = propertyInfo.propertyVariety.defaultPropertyMerge
            switch propertyInfo.merge ?? defaultMerge {
            case .mergeableProtocol:
                expr = "merged.\(varName) = try self.\(varName).merged(withSubordinate: other.\(varName), commonAncestor: commonAncestor.\(varName))"
            case .arrayMerge:
                let isOptional = varType.hasSuffix("]?")
                guard varType.hasPrefix("[") && (varType.hasSuffix("]") || isOptional) else {
                    throw ForkedModelError.propertyMergeAndTypeAreIncompatible
                }
                var elementType = varType.dropFirst().dropLast()
                if isOptional { elementType = elementType.dropLast() }
                expr = mergeExpr(mergerSetup: "let merger = ArrayMerger<\(elementType)>()")
            case .arrayOfIdentifiableMerge:
                let isOptional = varType.hasSuffix("]?")
                guard varType.hasPrefix("[") && (varType.hasSuffix("]") || isOptional) else {
                    throw ForkedModelError.propertyMergeAndTypeAreIncompatible
                }
                var elementType = varType.dropFirst().dropLast()
                if isOptional { elementType = elementType.dropLast() }
                expr = mergeExpr(mergerSetup: "let merger = ArrayOfIdentifiableMerger<\(elementType)>()")
            case .setMerge:
                guard varType.hasPrefix("Set<") else {
                    throw ForkedModelError.propertyMergeAndTypeAreIncompatible
                }
                let elementType = varType.dropFirst(4).dropLast()
                expr = mergeExpr(mergerSetup: "let merger = SetMerger<\(elementType)>()")
            case .dictionaryMerge:
                guard let (key, value) = ForkedModelMacro.extractKeyAndValueTypes(from: varType) else {
                    throw ForkedModelError.propertyMergeAndTypeAreIncompatible
                }
                expr = mergeExpr(mergerSetup: "let merger = DictionaryMerger<\(key), \(value)>()")
            case .textMerge:
                guard varType == "String" else {
                    throw ForkedModelError.propertyMergeAndTypeAreIncompatible
                }
                expr = mergeExpr(mergerSetup: "let merger = TextMerger()")
            }
            
            expressions.append(expr)
        }
        
        // Generate backed expression for each variable
        for propertyInfo in backedPropertyVars {
            let varSyntax = propertyInfo.varSyntax
            let varName = varSyntax.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
            let expr: String
            let backedVarName = BackedPropertyMacro.backingPropertyPrefix + varName
            switch propertyInfo.backing {
            case .mergeableValue, .mergeableArray, .mergeableSet, .mergeableDictionary:
                expr =
                    """
                    merged.\(backedVarName) = try self.\(backedVarName).merged(withSubordinate: other.\(backedVarName), commonAncestor: commonAncestor.\(backedVarName))
                    """
            }
            
            expressions.append(expr)
        }
        
        // generate extension syntax
        let declSyntax: DeclSyntax
        if expressions.isEmpty {
            declSyntax =
                """
                extension \(type.trimmed): Forked.Mergeable {
                    public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                        return self
                    }
                }
                """
        } else {
            declSyntax =
                """
                extension \(type.trimmed): Forked.Mergeable {
                    public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                        var merged = self
                        \(raw: expressions.joined(separator: "\n"))
                        return merged
                    }
                }
                """
        }
        return declSyntax.as(ExtensionDeclSyntax.self)!
    }
    
    private static func extensionDeclSyntax(from string: String) throws -> ExtensionDeclSyntax {
        try ExtensionDeclSyntax(
            .init(stringLiteral: string)
        )
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingConformancesOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [(TypeSyntax, GenericWhereClauseSyntax?)] {
        if extractVersion(from: node) != nil {
            // Create a proper TypeSyntax for VersionedModel
            return [(TypeSyntax("Forked.VersionedModel"), nil)]
        }
        return []
    }

    private static func extractVersion(from node: AttributeSyntax) -> Int? {
        guard let argumentList = node.arguments?.as(LabeledExprListSyntax.self) else {
            return nil
        }
        
        for argument in argumentList {
            if argument.label?.text == versionLabel,
               let integerExpr = argument.expression.as(IntegerLiteralExprSyntax.self) {
                return Int(integerExpr.literal.text)
            }
        }
        
        return nil
    }
}

