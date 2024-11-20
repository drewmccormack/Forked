import SwiftSyntax
import SwiftSyntaxMacros
import ForkedMerge

private let mergedLabel = "Merged"
private let mergeAlgorithmLabel = "using"

private let backedLabel = "Backed"
private let backingTypeLabel = "by"

extension VariableDeclSyntax {
    
    func propertyMerge() throws -> PropertyMerge? {
        let propertyAttribute = self.attributes.first { attribute in
            attribute.as(AttributeSyntax.self)?.attributeName.trimmedDescription == mergedLabel
        }
        guard let propertyAttribute else { return nil }
        
        var propertyMerge: PropertyMerge = .mergableProtocol
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
    
    func propertyBacking() throws -> PropertyBacking? {
        let propertyAttribute = self.attributes.first { attribute in
            attribute.as(AttributeSyntax.self)?.attributeName.trimmedDescription == backedLabel
        }
        guard let propertyAttribute else { return nil }
        
        var propertyBacking: PropertyBacking = .register
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
    
//    func initialValue() throws -> String? {
//        let propertyAttribute = self.attributes.first { attribute in
//            attribute.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "ForkedProperty"
//        }
//        guard let propertyAttribute else { return nil }
//
//        if let argumentList = propertyAttribute.as(AttributeSyntax.self)?.arguments?.as(LabeledExprListSyntax.self) {
//            argloop: for argument in argumentList {
//                if argument.label?.text == "mergeWith",
//                   let expr = argument.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text {
//                    if let algorithm = PropertyMerge(rawValue: expr) {
//                        propertyMerge = algorithm
//                        break argloop
//                    } else {
//                        throw ForkedModelError.invalidPropertyMerge
//                    }
//                }
//            }
//        }
//
//        return propertyMerge
//    }
}
