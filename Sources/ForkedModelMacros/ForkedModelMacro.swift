import SwiftSyntax
import SwiftSyntaxMacros
import ForkedMerge

private struct MergePropertyVar {
    var varSyntax: VariableDeclSyntax
    var merge: PropertyMerge
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
        
        // Check if the struct already conforms to Mergable
        let alreadyConformsToCodable = structDecl.inheritanceClause?.inheritedTypes.contains {
            $0.type.trimmedDescription == "Mergable" || $0.type.trimmedDescription == "Forked.Mergable"
        } ?? false
        
        // If it already conforms to Mergable, throw an error
        guard !alreadyConformsToCodable else {
            throw ForkedModelError.conformsToMergable
        }
        
        // Make sure the struct has defaults for all properties that are stored and non-optional
        guard structDecl.allStoredPropertiesHaveDefaultValue else {
            throw ForkedModelError.nonOptionalStoredPropertiesMustHaveDefaultValues
        }
        
        // Get all vars
        let allPropertyVars: [VariableDeclSyntax] = structDecl.memberBlock.members.compactMap { member -> VariableDeclSyntax? in
            guard let varSyntax = member.decl.as(VariableDeclSyntax.self) else { return nil }
            return varSyntax
        }
        
        // Gather names of all mergable properties
        let mergePropertyVars: [MergePropertyVar] = try structDecl.memberBlock.members.compactMap { member -> MergePropertyVar? in
            guard let varSyntax = member.decl.as(VariableDeclSyntax.self),
                  let propertyMerge = try varSyntax.propertyMerge()
                else { return nil }
            return MergePropertyVar(varSyntax: varSyntax, merge: propertyMerge)
        }
        
        // Gather names of all backed properties
        let backedPropertyVars: [BackedPropertyVar] = try structDecl.memberBlock.members.compactMap { member -> BackedPropertyVar? in
            guard let varSyntax = member.decl.as(VariableDeclSyntax.self),
                  let backing = try varSyntax.propertyBacking()
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
                if  let anyEquatableSelf = ForkedEquatable(self.\(varName)),
                    case let anyEquatableCommon = commonAncestor.flatMap({ ForkedEquatable($0.\(varName)) }) {
                    merged.\(varName) = anyEquatableSelf != anyEquatableCommon ? self.\(varName) : other.\(varName)
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
            switch propertyInfo.merge {
            case .mergableProtocol:
                expr =
                    """
                    merged.\(varName) = try self.\(varName).merged(withOlderConflicting: other.\(varName), commonAncestor: commonAncestor?.\(varName))
                    """
            case .arrayMerge:
                guard varType.hasPrefix("[") && varType.hasSuffix("]") else {
                    throw ForkedModelError.propertyMergeAndTypeAreIncompatible
                }
                let elementType = varType.dropFirst().dropLast()
                expr =
                    """
                    do {
                        let merger = ValueArrayMerger<\(elementType)>()
                        merged.\(varName) = try merger.merge(self.\(varName), withOlderConflicting: other.\(varName), commonAncestor: commonAncestor?.\(varName))
                    }
                    """
            case .textMerge:
                guard varType == "String" else {
                    throw ForkedModelError.propertyMergeAndTypeAreIncompatible
                }
                expr =
                    """
                    do {
                        let merger = TextMerger()
                        merged.\(varName) = try merger.merge(self.\(varName), withOlderConflicting: other.\(varName), commonAncestor: commonAncestor?.\(varName))
                    }
                    """
            }
            
            expressions.append(expr)
        }
        
        // Generate backed expression for each variable
        for propertyInfo in backedPropertyVars {
            let varSyntax = propertyInfo.varSyntax
            let varName = varSyntax.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
            let expr: String
            switch propertyInfo.backing {
            case .register:
                expr =
                    """
                    merged.\(BackedPropertyMacro.backingPropertyPrefix + varName) = try self.\(BackedPropertyMacro.backingPropertyPrefix + varName).merged(withOlderConflicting: other.\(BackedPropertyMacro.backingPropertyPrefix + varName), commonAncestor: commonAncestor?.\(BackedPropertyMacro.backingPropertyPrefix + varName))
                    """
            }
            
            expressions.append(expr)
        }
        
        // generate extension syntax
        let declSyntax: DeclSyntax
        if expressions.isEmpty {
            declSyntax = """
                extension \(type.trimmed): ForkedModel.Mergable {
                    public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
                        return self
                    }
                }
                """
        } else {
            declSyntax = """
                extension \(type.trimmed): ForkedModel.Mergable {
                    public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
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

