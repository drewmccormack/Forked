import Foundation

public enum MergeAction: Equatable, Sendable {
    case none
    case fastForward
    case resolveConflict
}

