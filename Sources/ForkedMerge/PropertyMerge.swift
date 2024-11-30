
/// The algorithm used to merge changes to a property.
/// Some properties know how to merge themselves; they conform to `Mergeable`.
/// Other types have no intrinsic merge, but can be merged by a `Merger`.
public enum PropertyMerge: String {
    /// The property must be a `Mergeable` type, and will be merged accordingly
    /// to the `Mergeable` protocol.
    /// This is the default algorithm if `@Merged` has been applied with no
    /// algorithm stated.
    case mergeableProtocol
    
    /// Will merge as an array of values. When there is a conflict, it will
    /// determine the changes made to each version, and merge with an
    /// algorithm that keeps related changes together (eg editing a word).
    /// Does not guarantee uniqueness of elements after merge:
    /// there can be duplicates created, so it is more suitable to value types
    /// like characters in a string. than it is to identifiable types.
    case arrayMerge
    
    /// Will merge sets of values. When there is a conflict, it will handle
    /// it using a MergeableSet for each set of changes.
    case setMerge
    
    /// Merges dictionaries. When there is a conflict, it will merge using
    /// a MergeableDictionary for each dictionary. If the value type is
    /// `Mergeable`, the dictionary will be merged recursing into the values.
    case dictionaryMerge
    
    /// Applies the `array` merge algorithm to the characters in a string.
    /// This is suitable for any type of shared text, which may
    /// have conflicting edits, like a collaborative editor.
    /// The variable must be a `String`.
    case textMerge
}
