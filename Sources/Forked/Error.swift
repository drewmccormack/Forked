import Foundation

public enum Error: Swift.Error {
    case unexpectedError(any Swift.Error)
    case attemptToAccessNonExistentFork(Fork)
    case attemptToDeleteMainFork
    case attemptToCreateExistingFork(Fork)
    case attemptToAccessNonExistentCommitInFork(Fork)
    case attemptToAccessNonExistentVersion(Version, Fork)
    case attemptToReplaceExistingVersion(Version, Fork)
}
