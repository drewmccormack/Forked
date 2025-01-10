
public enum ForkedModelError: Error, CustomStringConvertible {
    case appliedToNonStruct
    case appliedToNonVariable
    case conformsToMergeable
    case conformsToVersionedModel
    case invalidPropertyMerge
    case invalidPropertyBacking
    case propertyMergeAndTypeAreIncompatible
    case propertyBackingAndTypeAreIncompatible
    case nonOptionalStoredPropertiesMustHaveDefaultValues

    public var description: String {
        switch self {
        case .appliedToNonStruct:
            return "@ForkedModel can only be applied to structs"
        case .appliedToNonVariable:
            return "@Merged can only be applied to properties"
        case .conformsToMergeable:
            return "@ForkedModel should not explicitly conform to Mergeable protocol"
        case .conformsToVersionedModel:
            return "@ForkedModel should not explicitly conform to VersionedModel protocol"
        case .invalidPropertyMerge:
            return "@Merged has invalid merge algorithm"
        case .invalidPropertyBacking:
            return "@Backed has invalid backing"
        case .propertyMergeAndTypeAreIncompatible:
            return "@Merged has a merge algorithm that is incompatible with the type"
        case .propertyBackingAndTypeAreIncompatible:
            return "@Backed has a backing type that is incompatible with the property type"
        case .nonOptionalStoredPropertiesMustHaveDefaultValues:
            return "Non-optional stored properties in a ForkedModel struct must have default values"
        }
    }
}
