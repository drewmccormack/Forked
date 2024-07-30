import Foundation

public enum MergeAction: Equatable, Sendable {
    case none
    case mainForkFastForward
    case auxiliaryForkFastForward
    case resolveConflict
}

