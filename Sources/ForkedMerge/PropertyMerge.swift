
/// The algorithm used to merge changes to a property.
/// Some properties know how to merge themselves; they conform to `Mergable`.
/// Other types have no intrinsic merge, but can be merged by a `Merger`.
public enum PropertyMerge: String {
    /// The property must be a `Mergable` type, and will be merged accordingly
    /// to the `Mergable` protocol.
    /// This is the default algorithm if `@Merged` has been applied with no
    /// algorithm stated.
    case mergableProtocol
    
    /// Will merge as an array of values. When there is a conflict, it will
    /// determine the changes made to each version, and merge with an
    /// algorithm that keeps related changes together (eg editing a word).
    /// Does not guarantee uniqueness of elements after merge:
    /// there can be duplicates created, so it is more suitable to value types
    /// like characters in a string. than it is to identifiable types.
    case arrayMerge
    
    /// Applies the `array` merge algorithm to the characters in a string.
    /// This is suitable for any type of shared text, which may
    /// have conflicting edits, like a collaborative editor.
    /// The variable must be a `String`.
    case textMerge
}
