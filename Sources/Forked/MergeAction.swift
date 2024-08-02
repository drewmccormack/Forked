import Foundation

/// The action taken when two forks are merged.
public enum MergeAction: Equatable, Sendable {
    /// No action was taken. The two forks were already at the same version.
    case none
    
    /// One of the forks was ahead of the other, and the other had no new commits.
    /// So the fork with older version was simply made equal to the newer fork version.
    /// This is known as a "fast forward".
    case fastForward
    
    /// The two forks had both changed since the common ancestor version.
    /// A `Resolver` was used to merge the two, with the new commit added
    /// to the appropriate fork.
    case resolveConflict
}

