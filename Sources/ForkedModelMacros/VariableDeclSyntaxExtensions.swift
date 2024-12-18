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

    func isComputedVar() -> Bool {
        let accessors = bindings.compactMap {
            $0.accessorBlock?.accessors
        }
        // If no accessors, no reason to check
        guard !accessors.isEmpty else { return false }
        // For every accessors list check if at least one set is present otherwise return nil
        guard accessors.contains(where: { decl -> Bool in
            let accessorsDecl: AccessorDeclListSyntax
            switch decl {
            case .getter:
                // It is get only
                return true
            case .accessors(let accessors):
                // Has multiple accessors
                accessorsDecl = accessors
            }

            for accessor in accessorsDecl {
                // if has a set it is not computed
                guard accessor.accessorSpecifier == .keyword(.set) else { continue }
                return false
            }

            // If not setter found, it is computed
            return true
        }) else { return false }
        return true
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
