import SwiftSyntax
import SwiftSyntaxMacros

private struct PropertyInfo {
    var varSyntax: VariableDeclSyntax
    var mergeAlgorithm: MergeAlgorithm
}

public struct ForkedModelMacro: PeerMacro {
    
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        // Check that the node is a struct
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw ForkedModelError.appliedToNonStruct
        }
        
        // Check if the struct already conforms to Mergable
        let alreadyConformsToCodable = structDecl.inheritanceClause?.inheritedTypes.contains {
            $0.type.description == "Mergable" || $0.type.description == "Forked.Mergable"
        } ?? false
        
        // If it already conforms to Mergable, do nothing
        guard !alreadyConformsToCodable else {
            throw ForkedModelError.conformsToMergable
        }
        
        // Gather names of all stored properties
        let propertyInfos: [PropertyInfo] = try structDecl.memberBlock.members.compactMap { member -> PropertyInfo? in
            guard let varSyntax = member.decl.as(VariableDeclSyntax.self) else { return nil }
            let propertyAttribute = varSyntax.attributes.first { attribute in
                attribute.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "ForkedProperty"
            }
            guard let propertyAttribute else { return nil }
            
            var mergeAlgorithm: MergeAlgorithm = .property
            if let argumentList = propertyAttribute.as(AttributeSyntax.self)?.arguments?.as(LabeledExprListSyntax.self) {
                argloop: for argument in argumentList {
                    if argument.label?.text == "mergeAlgorithm",
                       let expr = argument.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text {
                        if let algorithm = MergeAlgorithm(rawValue: expr) {
                            mergeAlgorithm = algorithm
                            break argloop
                        } else {
                            throw ForkedModelError.invalidMergeAlgorithm
                        }
                    }
                }
            }
            
            return PropertyInfo(varSyntax: varSyntax, mergeAlgorithm: mergeAlgorithm)
        }
        
        // Generate merge expression for each variable
        var mergeExpressions: [String] = []
        for propertyInfo in propertyInfos {
            let varSyntax = propertyInfo.varSyntax
            let varName = varSyntax.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
            let varType = varSyntax.bindings.first!.typeAnnotation!.type.trimmedDescription
            let expr: String
            switch propertyInfo.mergeAlgorithm {
            case .property:
                expr =
                    """
                    merged.\(varName) = self.\(varName).merged(withOlderConflicting: other.\(varName), commonAncestor: commonAncestor?.\(varName))
                    """
            case .array:
                guard varType.hasPrefix("[") && varType.hasSuffix("]") else {
                    throw ForkedModelError.mergeAlgorithmAndTypeAreIncompatible
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
                    throw ForkedModelError.mergeAlgorithmAndTypeAreIncompatible
                }
                expr =
                    """
                    do {
                        let merger = StringMerger()
                        merged.\(varName) = try merger.merge(self.\(varName), withOlderConflicting: other.\(varName), commonAncestor: commonAncestor?.\(varName))
                    }
                    """
            }
            
            mergeExpressions.append(expr)
        }
        
        // generate extension syntax
        let typeName = structDecl.name.text
        let extensionSyntax: DeclSyntax = """
        extension \(raw: typeName): Forked.Mergable {
            public func merged(withOlderConflicting other: Self, commonAncestor: Self?) throws -> Self {
                var merged = self
                \(raw: mergeExpressions.joined(separator: "\n"))
                return merged
            }
        }
        """
        
        return [extensionSyntax]
    }
}
