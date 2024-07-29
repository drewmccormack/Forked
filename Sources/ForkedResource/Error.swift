import Foundation

public enum Error: Swift.Error {
    case unexpectedError(any Swift.Error)
    case attemptToAccessNonExistentFork(Fork)
    case attemptToDeleteMainFork
    case attemptToCreateExistingFork(Fork)
}
