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
        // but in this case, no accessor may be provided, so each declared var it may not be a computed var
        guard bindings.count == 1 else { return false }

        // If not accessors are presents, then the variable is in the form "var foo: Int = 3", which is by definition not a computed variable
        guard let accessorBlock = bindings.first!.accessorBlock else {
            return false
        }

        let accessorsList: AccessorDeclListSyntax

        switch accessorBlock.accessors {
        case .getter:
            // If the block is a "getter" block, then the var is computed
            // ex. var foo: Int { 3 }
            return true
        case .accessors(let accessors):
            accessorsList = accessors
        }

        var containsGetter: Bool = false
        var containsSetter: Bool = false

        // The variable is a "computed variable" only if a getter is present in the list of its accessors without a setter.
        // Check that the accessorsList may contains different accessors like "didSet" or "willSet", and no "set" and "get".
        // In this case the var is not computed
        // ex. var foo: Int = 4 { didSet { print("hello") } }
        for accessor in accessorsList {
            if accessor.accessorSpecifier.tokenKind == .keyword(.set) {
                containsSetter = true
                continue
            }

            if accessor.accessorSpecifier.tokenKind == .keyword(.get) {
                containsGetter = true
                continue
            }
        }

        if containsGetter, !containsSetter {
            return true
        }

        return false
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
