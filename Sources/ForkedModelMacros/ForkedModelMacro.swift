import SwiftSyntax
import SwiftSyntaxMacros
import ForkedMerge

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

public struct ForkedModelMacro: ExtensionMacro {
    public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax, providingExtensionsOf type: some TypeSyntaxProtocol, conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        // Check that the node is a struct
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw ForkedModelError.appliedToNonStruct
        }
        
        // Check if the struct already conforms to Mergeable
        let alreadyConformsToCodable = structDecl.inheritanceClause?.inheritedTypes.contains {
            $0.type.trimmedDescription == "Mergeable" || $0.type.trimmedDescription == "Forked.Mergeable"
        } ?? false
        
        // If it already conforms to Mergeable, throw an error
        guard !alreadyConformsToCodable else {
            throw ForkedModelError.conformsToMergeable
        }
        
        // Make sure the struct has defaults for all properties that are stored and non-optional
        guard structDecl.allStoredPropertiesHaveDefaultValue else {
            throw ForkedModelError.nonOptionalStoredPropertiesMustHaveDefaultValues
        }

        // Get all vars
        let allPropertyVars: [VariableDeclSyntax] = structDecl.memberBlock.members.compactMap { member -> VariableDeclSyntax? in
            guard let varSyntax = member.decl.as(VariableDeclSyntax.self) else { return nil }
            guard !varSyntax.isComputedVar() else { return nil }
            return varSyntax
        }
        
        // Gather names of all mergeable properties
        let mergePropertyVars: [MergePropertyVar] = try structDecl.memberBlock.members.compactMap { member -> MergePropertyVar? in
            guard let varSyntax = member.decl.as(VariableDeclSyntax.self), varSyntax.isMerged(), !varSyntax.isComputedVar()
                else { return nil }
            let propertyMerge = try varSyntax.propertyMerge()
            return MergePropertyVar(varSyntax: varSyntax, merge: propertyMerge, propertyVariety: varSyntax.propertyVariety())
        }
        
        // Gather names of all backed properties
        let backedPropertyVars: [BackedPropertyVar] = try structDecl.memberBlock.members.compactMap { member -> BackedPropertyVar? in
            guard let varSyntax = member.decl.as(VariableDeclSyntax.self),
                  let backing = try varSyntax.propertyBacking(),
                  !varSyntax.isComputedVar()
                else { return nil }
            return BackedPropertyVar(varSyntax: varSyntax, backing: backing)
        }
        
        // Variables that should use the default merge
        let defaultMergeVars = allPropertyVars.filter { varSyntax in
            !mergePropertyVars.contains { $0.varSyntax == varSyntax } &&
            !backedPropertyVars.contains { $0.varSyntax == varSyntax }
        }
        
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
            let expr: String
            
            func mergeExpr(merger: String) -> String {
                "merged.\(varName) = try merge(withMergerType: \(merger).self, dominant: self.\(varName), subordinate: other.\(varName), commonAncestor: commonAncestor.\(varName))"
            }
            
            // If no merge given, fall back on default for variety
            let defaultMerge = propertyInfo.propertyVariety.defaultPropertyMerge
            switch propertyInfo.merge ?? defaultMerge {
            case .mergeableProtocol:
                expr = "merged.\(varName) = try self.\(varName).merged(withSubordinate: other.\(varName), commonAncestor: commonAncestor.\(varName))"
            case .arrayMerge:
                expr = mergeExpr(merger: "ArrayMerger")
            case .arrayOfIdentifiableMerge:
                expr = mergeExpr(merger: "ArrayOfIdentifiableMerger")
            case .setMerge:
                expr = mergeExpr(merger: "SetMerger")
            case .dictionaryMerge:
                expr = mergeExpr(merger: "DictionaryMerger")
            case .textMerge:
                expr = mergeExpr(merger: "TextMerger")
            }
            
            expressions.append(expr)
        }
        
        // Generate backed expression for each variable
        for propertyInfo in backedPropertyVars {
            let varSyntax = propertyInfo.varSyntax
            let varName = varSyntax.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
            let expr: String
            switch propertyInfo.backing {
            case .mergeableValue, .mergeableArray, .mergeableSet, .mergeableDictionary:
                expr =
                    """
                    merged.\(BackedPropertyMacro.backingPropertyPrefix + varName) = try self.\(BackedPropertyMacro.backingPropertyPrefix + varName).merged(withSubordinate: other.\(BackedPropertyMacro.backingPropertyPrefix + varName), commonAncestor: commonAncestor.\(BackedPropertyMacro.backingPropertyPrefix + varName))
                    """
            }
            
            expressions.append(expr)
        }
        
        // generate extension syntax
        let declSyntax: DeclSyntax
        if expressions.isEmpty {
            declSyntax = """
                extension \(type.trimmed): Forked.Mergeable {
                    public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                        return self
                    }
                }
                """
        } else {
            declSyntax = """
                extension \(type.trimmed): Forked.Mergeable {
                    public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
                        var merged = self
                        \(raw: expressions.joined(separator: "\n"))
                        return merged
                    }
                }
                """
        }
        let extensionDecl = declSyntax.as(ExtensionDeclSyntax.self)!
        return [extensionDecl]
    }
    
    private static func extensionDeclSyntax(from string: String) throws -> ExtensionDeclSyntax {
        try ExtensionDeclSyntax(
            .init(stringLiteral: string)
        )
    }
}

