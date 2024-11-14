import Foundation

/// The action taken when two forks are merged.
public enum MergeAction: Equatable, Sendable {
    /// No action was taken. The two forks were already at the same version.
    case none
    
    /// The destination fork is behind, and it has no new commits itself.
    /// So the destination fork version was simply made equal to the newer fork version.
    /// This is known as a "fast forward".
    case fastForward
    
    /// The two forks had both changed since the common ancestor version.
    /// They were merged to produce a new value for the destination fork.
    case resolveConflict
}

