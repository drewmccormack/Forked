import SwiftSyntax
import SwiftSyntaxMacros
import ForkedMerge

private struct PropertyInfo {
    var varSyntax: VariableDeclSyntax
    var propertyMergeAlgorithm: PropertyMergeAlgorithm
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
        
        // If it already conforms to Mergable, do nothing
        guard !alreadyConformsToCodable else {
            throw ForkedModelError.conformsToMergable
        }
        
        // Gather names of all stored properties
        let propertyInfos: [PropertyInfo] = try structDecl.memberBlock.members.compactMap { member -> PropertyInfo? in
            guard let varSyntax = member.decl.as(VariableDeclSyntax.self),
                  let propertyMergeAlgorithm = try varSyntax.propertyMergeAlgorithm()
                else { return nil }
            return PropertyInfo(varSyntax: varSyntax, propertyMergeAlgorithm: propertyMergeAlgorithm)
        }
        
        // Generate merge expression for each variable
        var mergeExpressions: [String] = []
        for propertyInfo in propertyInfos {
            let varSyntax = propertyInfo.varSyntax
            let varName = varSyntax.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
            let varType = varSyntax.bindings.first!.typeAnnotation!.type.trimmedDescription
            let expr: String
            switch propertyInfo.propertyMergeAlgorithm {
            case .parent:
                expr =
                    """
                    merged.\(varName) = self.\(varName)
                    """
            case .mergable:
                expr =
                    """
                    merged.\(varName) = self.\(varName).merged(withOlderConflicting: other.\(varName), commonAncestor: commonAncestor?.\(varName))
                    """
            case .array:
                guard varType.hasPrefix("[") && varType.hasSuffix("]") else {
                    throw ForkedModelError.propertyMergeAlgorithmAndTypeAreIncompatible
                }
                let elementType = varType.dropFirst().dropLast()
                expr =
                    """
                    do {
                        let merger = ValueArrayMerger<\(elementType)>()
                        merged.\(varName) = try merger.merge(self.\(varName), withOlderConflicting: other.\(varName), commonAncestor: commonAncestor?.\(varName))
                    }
                    """
            case .string:
                guard varType == "String" else {
                    throw ForkedModelError.propertyMergeAlgorithmAndTypeAreIncompatible
                }
                expr =
                    """
                    do {
                        let merger = StringMerger()
                        merged.\(varName) = try merger.merge(self.\(varName), withOlderConflicting: other.\(varName), commonAncestor: commonAncestor?.\(varName))
                    }
                    """
            case .mostRecent:
                expr =
                    """
                    merged._\(varName) = self._\(varName).merged(withOlderConflicting: other._\(varName), commonAncestor: commonAncestor?._\(varName))
                    """
            }
            
            mergeExpressions.append(expr)
        }
        
        // generate extension syntax
        let declSyntax: DeclSyntax
        if mergeExpressions.isEmpty {
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
                        \(raw: mergeExpressions.joined(separator: "\n"))
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

extension VariableDeclSyntax {
    
    func propertyMergeAlgorithm() throws -> PropertyMergeAlgorithm? {
        let propertyAttribute = self.attributes.first { attribute in
            attribute.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "ForkedProperty"
        }
        guard let propertyAttribute else { return nil }
        
        var propertyMergeAlgorithm: PropertyMergeAlgorithm = .mergable
        if let argumentList = propertyAttribute.as(AttributeSyntax.self)?.arguments?.as(LabeledExprListSyntax.self) {
            argloop: for argument in argumentList {
                if argument.label?.text == "mergeWith",
                   let expr = argument.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text {
                    if let algorithm = PropertyMergeAlgorithm(rawValue: expr) {
                        propertyMergeAlgorithm = algorithm
                        break argloop
                    } else {
                        throw ForkedModelError.invalidPropertyMerge
                    }
                }
            }
        }
        
        return propertyMergeAlgorithm
    }
    
}
