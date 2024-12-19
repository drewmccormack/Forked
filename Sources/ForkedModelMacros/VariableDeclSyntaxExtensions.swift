import SwiftSyntax
import SwiftSyntaxMacros
import ForkedMerge

private let mergedLabel = "Merged"
private let mergeAlgorithmLabel = "using"

private let backedLabel = "Backed"
private let backingTypeLabel = "by"

extension VariableDeclSyntax {
    
    func isMerged() -> Bool {
        self.attributes.contains { attribute in
            attribute.as(AttributeSyntax.self)?.attributeName.trimmedDescription == mergedLabel
        }
    }
    

    func isComputed() -> Bool {
        // Each variable may have multiple declarations on the same line (ex. var foo: String, bar: String),
        // but computed variables must always have 1.
        guard bindings.count == 1 else {
            return false
        }

        // If no accessors are present then the variable is a
        // stored variable
        guard let accessorBlock = bindings.first!.accessorBlock else {
            return false
        }

        // Get accessors list
        let accessorsList: AccessorDeclListSyntax
        switch accessorBlock.accessors {
        case .getter:
            return true
        case .accessors(let accessors):
            accessorsList = accessors
        }

        // The variable is a "computed variable" only if a getter is present in the list
        // of its accessors, with no setter present.
        let containsGetter = accessorsList.contains { $0.accessorSpecifier.tokenKind == .keyword(.get) }
        let containsSetter = accessorsList.contains { $0.accessorSpecifier.tokenKind == .keyword(.set) }
        return containsGetter && !containsSetter
    }

    func propertyMerge() throws -> PropertyMerge? {
        let propertyAttribute = self.attributes.first { attribute in
            attribute.as(AttributeSyntax.self)?.attributeName.trimmedDescription == mergedLabel
        }
        guard let propertyAttribute else { return nil }
        
        var propertyMerge: PropertyMerge?
        if let argumentList = propertyAttribute.as(AttributeSyntax.self)?.arguments?.as(LabeledExprListSyntax.self) {
            argloop: for argument in argumentList {
                if argument.label?.text == mergeAlgorithmLabel,
                   let expr = argument.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text {
                    if let algorithm = PropertyMerge(rawValue: expr) {
                        propertyMerge = algorithm
                        break argloop
                    } else {
                        throw ForkedModelError.invalidPropertyMerge
                    }
                }
            }
        }
        
        return propertyMerge
    }
    
    func propertyVariety() -> PropertyVariety {
        let binding = bindings.first!
        let originalType = binding.typeAnnotation!.type.trimmedDescription

        let result: PropertyVariety
        if nil != extractKeyAndValueTypes(from: originalType) {
            result = .dictionary
        } else if originalType.hasPrefix("Set<") && originalType.hasSuffix(">") {
            result = .set
        } else if originalType.hasPrefix("[") && originalType.hasSuffix("]") {
            result = .array
        } else if originalType == "String" {
            result = .text
        } else {
            result = .singleValue
        }
 
        return result
    }
    
    func propertyBacking() throws -> PropertyBacking? {
        let propertyAttribute = self.attributes.first { attribute in
            attribute.as(AttributeSyntax.self)?.attributeName.trimmedDescription == backedLabel
        }
        guard let propertyAttribute else { return nil }
        
        var propertyBacking: PropertyBacking = .mergeableValue
        if let argumentList = propertyAttribute.as(AttributeSyntax.self)?.arguments?.as(LabeledExprListSyntax.self) {
            argloop: for argument in argumentList {
                if argument.label?.text == backingTypeLabel,
                   let expr = argument.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text {
                    if let b = PropertyBacking(rawValue: expr) {
                        propertyBacking = b
                        break argloop
                    } else {
                        throw ForkedModelError.invalidPropertyBacking
                    }
                }
            }
        }
        
        return propertyBacking
    }

}
