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
        return subdirectories.filter { $0.hasDirectoryPath }.map { Fork(name: $0.lastPathComponent) }
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

    private struct VersionMetadata: Codable {
        let count: UInt64
        let timestamp: Date
    }
    
    private func metadataURL(for version: Version, in fork: Fork) -> URL {
        rootDirectory
            .appendingPathComponent(fork.name)
            .appendingPathComponent("\(version.count).metadata")
    }
    
    private func dataURL(for version: Version, in fork: Fork) -> URL {
        rootDirectory
            .appendingPathComponent(fork.name)
            .appendingPathComponent(String(version.count))
    }

    public func content(of fork: Fork, at version: Version) throws -> CommitContent<Data> {
        let forkDirectory = rootDirectory.appendingPathComponent(fork.name)
        let dataURL = forkDirectory.appendingPathComponent(String(version.count))
        let metadataURL = forkDirectory.appendingPathComponent("\(version.count).metadata")
        
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            throw Error.attemptToAccessNonExistentVersion(version, fork)
        }
        
        if FileManager.default.fileExists(atPath: dataURL.path) {
            return .resource(try Data(contentsOf: dataURL))
        } else {
            return .none
        }
    }

    public func store(_ commit: Commit<Data>, in fork: Fork) throws {
        let forkDirectory = rootDirectory.appendingPathComponent(fork.name)
        guard FileManager.default.fileExists(atPath: forkDirectory.path) else {
            throw Error.attemptToAccessNonExistentFork(fork)
        }
        
        let dataURL = forkDirectory.appendingPathComponent(String(commit.version.count))
        let metadataURL = forkDirectory.appendingPathComponent("\(commit.version.count).metadata")
        
        guard !FileManager.default.fileExists(atPath: metadataURL.path) else {
            throw Error.attemptToReplaceExistingVersion(commit.version, fork)
        }
        
        // Save metadata
        let metadata = VersionMetadata(count: commit.version.count, timestamp: commit.version.timestamp)
        let encoder = JSONEncoder()
        try encoder.encode(metadata).write(to: metadataURL)
        
        // Save content if it's not .none
        if case .resource(let data) = commit.content {
            try data.write(to: dataURL)
        }
    }

    public func versions(storedIn fork: Fork) throws -> Set<Version> {
        let forkDirectory = rootDirectory.appendingPathComponent(fork.name)
        guard FileManager.default.fileExists(atPath: forkDirectory.path) else {
            throw Error.attemptToAccessNonExistentFork(fork)
        }
        
        let files = try FileManager.default.contentsOfDirectory(at: forkDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        
        let decoder = JSONDecoder()
        return Set(files.compactMap { url in
            guard url.pathExtension == "metadata" else { return nil }
            guard let metadata = try? decoder.decode(VersionMetadata.self, from: Data(contentsOf: url)) else { return nil }
            return Version(count: metadata.count, timestamp: metadata.timestamp)
        })
    }

    public func removeCommit(at version: Version, from fork: Fork) throws {
        let forkDirectory = rootDirectory.appendingPathComponent(fork.name)
        let dataURL = forkDirectory.appendingPathComponent(String(version.count))
        let metadataURL = forkDirectory.appendingPathComponent("\(version.count).metadata")
        
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            throw Error.attemptToAccessNonExistentVersion(version, fork)
        }
        
        try FileManager.default.removeItem(at: metadataURL)
        if FileManager.default.fileExists(atPath: dataURL.path) {
            try FileManager.default.removeItem(at: dataURL)
        }
    }

    private func createDirectoryIfNeeded(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }

}
