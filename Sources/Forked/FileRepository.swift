import Foundation

/// A FileRepository stores its contents in a directory structure on disk.
/// Each fork corresponds to a subdirectory, and files are stored within those subdirectories.
public final class FileRepository: Repository {
    private let rootDirectory: URL

    /// Initialize the FileRepository with a root directory. Creates the directory if it doesn't exist.
    public init(rootDirectory: URL) throws {
        self.rootDirectory = rootDirectory
        try createDirectoryIfNeeded(at: rootDirectory)
    }

    public var forks: [Fork] {
        guard let subdirectories = try? FileManager.default.contentsOfDirectory(at: rootDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            return []
        }
        return subdirectories.filter { $0.hasDirectoryPath }.map { Fork($0.lastPathComponent) }
    }

    public func create(_ fork: Fork, withInitialCommit commit: Commit<Data>) throws {
        let forkDirectory = rootDirectory.appendingPathComponent(fork.name)
        guard !FileManager.default.fileExists(atPath: forkDirectory.path) else {
            throw Error.attemptToCreateExistingFork(fork)
        }
        try createDirectoryIfNeeded(at: forkDirectory)
        try store(commit, in: fork)
    }

    public func delete(_ fork: Fork) throws {
        let forkDirectory = rootDirectory.appendingPathComponent(fork.name)
        guard FileManager.default.fileExists(atPath: forkDirectory.path) else {
            throw Error.attemptToAccessNonExistentFork(fork)
        }
        try FileManager.default.removeItem(at: forkDirectory)
    }

    public func versions(storedIn fork: Fork) throws -> Set<Version> {
        let forkDirectory = rootDirectory.appendingPathComponent(fork.name)
        guard FileManager.default.fileExists(atPath: forkDirectory.path) else {
            throw Error.attemptToAccessNonExistentFork(fork)
        }
        let files = try FileManager.default.contentsOfDirectory(at: forkDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        return Set(files.map { Version($0.lastPathComponent) })
    }

    public func removeCommit(at version: Version, from fork: Fork) throws {
        let forkDirectory = rootDirectory.appendingPathComponent(fork.name)
        let fileURL = forkDirectory.appendingPathComponent(version.id)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw Error.attemptToAccessNonExistentVersion(version, fork)
        }
        try FileManager.default.removeItem(at: fileURL)
    }

    public func content(of fork: Fork, at version: Version) throws -> Data {
        let forkDirectory = rootDirectory.appendingPathComponent(fork.name)
        let fileURL = forkDirectory.appendingPathComponent(version.id)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw Error.attemptToAccessNonExistentVersion(version, fork)
        }
        return try Data(contentsOf: fileURL)
    }

    public func store(_ commit: Commit<Data>, in fork: Fork) throws {
        let forkDirectory = rootDirectory.appendingPathComponent(fork.name)
        guard FileManager.default.fileExists(atPath: forkDirectory.path) else {
            throw Error.attemptToAccessNonExistentFork(fork)
        }
        let fileURL = forkDirectory.appendingPathComponent(commit.version.id)
        guard !FileManager.default.fileExists(atPath: fileURL.path) else {
            throw Error.attemptToReplaceExistingVersion(commit.version, fork)
        }
        try commit.content.write(to: fileURL)
    }
    

    private func createDirectoryIfNeeded(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
