import Foundation

/// Different versions of the resource currently stored in a particular fork.
internal enum ForkOccupation<Resource>: Equatable {
    case sameAsMain
    case leftBehindByMain(Commit<Resource>)
    case aheadOrConflictingWithMain(Commit<Resource>, commonAncestor: Commit<Resource>)
}
