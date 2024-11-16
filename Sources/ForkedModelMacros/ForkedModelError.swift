
public enum ForkedModelError: Error, CustomStringConvertible {
    case appliedToNonStruct
    case appliedToNonVariable
    case conformsToMergable
    case invalidMergeAlgorithm

    public var description: String {
        switch self {
        case .appliedToNonStruct:
            return "@ForkedModel can only be applied to structs"
        case .appliedToNonVariable:
            return "@ForkedProperty can only be applied to properties"
        case .conformsToMergable:
            return "@ForkedModel should not explicitly conform to Mergable protocol"
        case .invalidMergeAlgorithm:
            return "@Property has invalid merge algorithm"
        }
    }
}
