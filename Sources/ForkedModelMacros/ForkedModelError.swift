
public enum ForkedModelError: Error, CustomStringConvertible {
    case appliedToNonStruct
    case appliedToNonVariable
    case conformsToMergable
    case invalidPropertyMerge
    case invalidPropertyBacking
    case propertyMergeAndTypeAreIncompatible
    case propertyBackingAndTypeAreIncompatible

    public var description: String {
        switch self {
        case .appliedToNonStruct:
            return "@ForkedModel can only be applied to structs"
        case .appliedToNonVariable:
            return "@Merged can only be applied to properties"
        case .conformsToMergable:
            return "@ForkedModel should not explicitly conform to Mergable protocol"
        case .invalidPropertyMerge:
            return "@Merged has invalid merge algorithm"
        case .invalidPropertyBacking:
            return "@Backed has invalid backing"
        case .propertyMergeAndTypeAreIncompatible:
            return "@Merged has a merge algorithm that is incompatible with the type"
        case .propertyBackingAndTypeAreIncompatible:
            return "@Backed has a backing type that is incompatible with the property type"
        }
    }
}
