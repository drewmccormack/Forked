
/// Protocol to track the model version of a `ForkedResource`.
/// This isn't very important on a single device, but if syncing between
/// devices, it is important that a device that doesn't yet have the
/// latest version does not try to import data from that version.
/// If it does, it won't know how to handle it, and may lose data.
public protocol VersionedModel {
    
    /// The current version of the model for this resource (struct).
    /// It is generally best to start the current version at 0, and increase it by
    /// one whenever a change is made to the properties of a struct.
    /// If you have not being using `VersionedModel`, and add
    /// sync, you would use `0` if your model is unchanged, and `1` if
    /// it changed from the un-synced version. The old un-synced model
    /// will get a `modelVersion` of `nil`, which is treated as `0`.
    /// Using `1` will cause `Forked` to avoid merging the newer model
    /// into the old one.
    static var currentModelVersion: Int { get }
    
    /// When an object is created for the first time, or saved,
    /// this version is set to the most recent version (`currentModelVersion`).
    /// When loading data from disk (eg with `Codable`) or over a network, this
    /// can be compared with `currentModelVersion` to see if
    /// the model saved is a known version. If not, we should not
    /// try to merge with it.
    /// This is optional so that it is possible to add it to an existing
    /// model that was not versioned, and still use `Codable` migration.
    /// A value of `nil` is treated the same as `0`. 
    var modelVersion: Int? { get }
    
}

public extension VersionedModel {
    
    /// If the `version` is less or equal to the `currentVersion`
    /// it is considered to be known. Ie, it is a version from the past
    /// or a current version, and we can handle this version. It can
    /// be properly migrated.
    var canLoadModelVersion: Bool {
        (modelVersion ?? 0) <= Self.currentModelVersion
    }
    
}
