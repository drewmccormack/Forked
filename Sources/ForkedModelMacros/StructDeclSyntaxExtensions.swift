import SwiftSyntax
import SwiftSyntaxMacros

extension StructDeclSyntax {
    
    var allStoredPropertiesHaveDefaultValue: Bool {
        // Collect all stored properties
        let storedProperties = memberBlock.members.compactMap { member in
            member.decl.as(VariableDeclSyntax.self)
        }.flatMap { variableDecl in
            // Filter only stored properties
            variableDecl.bindings.compactMap { binding -> PatternBindingSyntax? in
                // Exclude computed properties
                guard binding.accessorBlock == nil else { return nil }
                return binding
            }
        }
        
        // Check for default values or optionals
        let propertiesWithoutDefaults = storedProperties.filter { property in
            if property.initializer != nil {
                return false // Explicit initializer exists
            }
            // Check if the property is an optional type
            guard (property.typeAnnotation?.type.as(OptionalTypeSyntax.self)) != nil else {
                return true // Not an optional and no initializer
            }
            return false // Optional without an explicit initializer defaults to nil
        }
        
        return propertiesWithoutDefaults.isEmpty
    }
    
}
