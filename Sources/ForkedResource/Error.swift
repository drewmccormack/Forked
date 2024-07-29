import Foundation

public enum Error: Swift.Error {
    case unexpectedError(any Swift.Error)
    case forkDoesNotExist(Fork)
    case attemptToAccessNonExistentFork
    case attemptToDeleteMainFork
    case attemptToCreateExistingFork
}
