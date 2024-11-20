
/// The storage used for a property. These storage types have built in
/// systems for merging. They maintain the information they need (eg history)
/// to properly merge even if with copies that have conflicting changes.
public enum PropertyBacking: String {
    /// This uses a `Register` type as the backing of the variable.
    /// The register stores a timestamp with the value whenever there is an update.
    /// A merge will choose the most recent updated value.
    case register
}
