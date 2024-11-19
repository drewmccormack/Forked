
/// The algorithm used to merge changes to a property.
/// Some properties know how to merge themselves; they conform to `Mergable`.
/// Other types have no intrinsic merge, but can be merged by a `Merger`.
public enum PropertyMergeAlgorithm: String {
    /// Is merged as a component of the parent value.
    /// For a purely local forked resource, this is equivalent to assigning the property
    /// to the value it has when the most recent change was made to the parent,
    /// whether that change was to this property or a different one.
    /// In other words, you are not guaranteed that the most recent change to
    /// this particular property will win. In most cases, it will work as expected, but
    /// if you must end up with the most recent value of a property, you could consider
    /// using `mostRecent` instead, which tracks timestamps for each property.
    case parent
    
    /// The property must be a `Mergable` type, and will be merged accordingly
    /// to the `Mergable` protocol.
    /// This is the default algorithm if `@ForkedProperty` has been applied with no
    /// algorithm stated.
    case mergable
    
    /// This uses a `Register` type as the backing of the variable.
    /// The register stores a timestamp with the value whenever there is an update.
    /// A merge will choose the most recent updated value.
    case mostRecent
    
    /// Will merge as an array of values. When there is a conflict, it will
    /// determine the changes made to each version, and merge with an
    /// algorithm that keeps related changes together (eg editing a word).
    /// Does not guarantee uniqueness of elements after merge:
    /// there can be duplicates created, so it is more suitable to value types
    /// like characters in a string. than it is to identifiable types.
    case array
    
    /// Applies the `array` merge algorithm to the characters in a string.
    /// This is suitable for any type of shared text, which may
    /// have conflicting edits, like a collaborative editor.
    /// The variable must be a `String`.
    case string
    
    public var needsBackingType: Bool {
        switch self {
        case .mostRecent:
            return true
        case .parent, .mergable, .array, .string:
            return false
        }
    }
}
