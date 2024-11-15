import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin

public enum ForkedModelError: Error, CustomStringConvertible {
    case appliedToNonStruct

    public var description: String {
        switch self {
        case .appliedToNonStruct:
            return "@Model can only be applied to structs"
        }
    }
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
            return []
        }
                
        // Gather names of all stored properties
        let mergeVariableSyntaxes: [VariableDeclSyntax] = structDecl.memberBlock.members.compactMap { member -> VariableDeclSyntax? in
            guard let varSyntax = member.decl.as(VariableDeclSyntax.self) else { return nil }
            let contains = varSyntax.attributes.contains { attribute in
                attribute.as(AttributeSyntax.self)?.attributeName.description == "@ForkedProperty"
            }
            return contains ? varSyntax : nil
        }
        
        // Generate merge expression for each variable
        var mergeExpressions: [String] = []
        for varSyntax in mergeVariableSyntaxes {
            let varName = varSyntax.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
            let expr = """
            merged.\(varName) = self.\(varName).merged(withOlderConflicting: other.\(varName), commonAncestor: commonAncestor?.\(varName))
            """
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
