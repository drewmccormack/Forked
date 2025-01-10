import Foundation

/// Any type conforming to this can be used in a 3-way merge
public protocol Mergeable: Equatable {
    
    /// Performs a 3-way merge, where `self` and `other` are the most recent versions,
    /// and `commonAncestor` is from a point in the past at which time the histories diverged.
    /// By comparing the recent values to the ancestor, you can determine what changed in each fork,
    /// and decide how to merge. Where it is not possible to merge changes from each, `self` should
    /// be considered the `dominant` fork, and `other` subordinate. If you must choose, choose `self`.
    func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self
    
    /// In general, 3-way merges are used in Forked. But when bootstrapping,
    /// there can be times when no common ancestor exists. Effectively we have
    /// to merge together unrelated values. For example, if you install an app on
    /// two offline devices, insert some data on each, and then take them online to
    /// sync. In this scenario, there is no common ancestor,
    /// but it would be nice to keep the data entered on each device.
    /// An even trickier case arises if two devices are fully synced up, but then the
    /// cloud data is reset. Effectively, the two data sets are now unrelated, and if you
    /// start them syncing again, the history relating them is lost, and there is no common
    /// ancestor. You can choose one or the other, but just blindly merging the two will
    /// lead to duplications (how often have we seen that in apps like Contacts?)
    /// 
    /// That's a lot of introduction, but it sets up this function. This function is effectively
    /// a 2-way merge. By default, it just returns `self`, which is considered the dominant
    /// copy of the data. But if you need special handling to bootstrap, you can "salvage"
    /// data from `other` and merge it in. It is even possible to setup a 3-way merge
    /// where you construct an initial value and use that as the common ancestor, but
    /// this may not work well for all properties. Often a combination of approaches is best
    /// for salvaging, eg, starting with a 3-way merge against the initial value, and then
    /// copying in properties from `self` where this 3-way merge doesn't do what you
    /// want.
    func salvaging(from other: Self) throws -> Self
    
}

public extension Mergeable {
    
    func salvaging(from other: Self) throws -> Self { self }
    
}

extension Optional: Mergeable where Wrapped: Mergeable {
    
    public func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
        if self == commonAncestor {
            return other
        } else if other == commonAncestor {
            return self
        } else {
            // Conflicting changes
            switch (self, other, commonAncestor) {
            case (nil, nil, _):
                return nil
            case (let s?, nil, _):
                return s
            case (nil, let o?, _):
                return o
            case (let s?, let o?, nil):
                return try s.salvaging(from: o)
            case (let s?, let o?, let c?):
                return try s.merged(withSubordinate: o, commonAncestor: c)
            }
        }
    }
    
}

extension Optional: @retroactive Identifiable where Wrapped: Identifiable {
    
    public var id: Wrapped.ID? {
        self?.id
    }
    
}
