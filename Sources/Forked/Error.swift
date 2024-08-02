import Foundation

/// Errors that can arise when  using `ForkedResource`
public enum Error: Swift.Error {
    case unexpectedError(any Swift.Error)
    case attemptToAccessNonExistentFork(Fork)
    case attemptToDeleteProtectedFork(Fork)
    case attemptToDeleteAllDataFromMainFork
    case attemptToCreateExistingFork(Fork)
    case attemptToAccessNonExistentCommitInFork(Fork)
    case attemptToAccessNonExistentVersion(Version, Fork)
    case attemptToReplaceExistingVersion(Version, Fork)
}
