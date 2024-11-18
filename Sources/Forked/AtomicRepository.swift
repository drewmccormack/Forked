import Foundation

/// An atomic repository is one that gets loaded completely into memory.
/// If the `Resource` it contains conforms to `Codable`, the `AtomicRepository` is
/// also `Codable`, and can be converted to a serialized form and saved as a file.
/// Saving and loading are atomic, that is, the whole repository is loaded from file, and the whole
/// file is written to disk.
public final class AtomicRepository<Resource>: Repository {
    private var forkToResource: [Fork:[Commit<Resource>]] = [:]
    
    /// If set, the persistence of the repo is managed for you. It will load and
    /// save as needed, though you can trigger the functions `persist` to save yourself too.
    /// If nil, `persist` and `load` do nothing, and you manually manage the repo.
    private let managedFileURL: URL?
    
    /// Persist using Codable
    public init(managedFileURL: URL) throws where Resource: Codable {
        self.managedFileURL = managedFileURL
        try? load()
    }
    
    /// Initialize with no persistence
    public init() {
        managedFileURL = nil
    }
    
    public var forks: [Fork] {
        Array(forkToResource.keys)
    }
    
    public func create(_ fork: Fork, withInitialCommit commit: Commit<Resource>) throws {
        guard forkToResource[fork] == nil else {
            throw Error.attemptToCreateExistingFork(fork)
        }
        forkToResource[fork] = [commit]
    }
    
    public func delete(_ fork: Fork) throws {
        guard forkToResource[fork] != nil else {
            throw Error.attemptToAccessNonExistentFork(fork)
        }
        forkToResource[fork] = nil
    }
    
    public func versions(storedIn fork: Fork) throws -> Set<Version> {
        guard let commits = forkToResource[fork] else {
            throw Error.attemptToAccessNonExistentFork(fork)
        }
        return Set(commits.map { $0.version })
    }
    
    public func removeCommit(at version: Version, from fork: Fork) throws {
        guard forkToResource[fork]?.first(where: { $0.version == version }) != nil else {
            throw Error.attemptToAccessNonExistentVersion(version, fork)
        }
        forkToResource[fork]!.removeAll(where: { $0.version == version })
    }
    
    public func content(of fork: Fork, at version: Version) throws -> CommitContent<Resource> {
        guard let commit = forkToResource[fork]?.first(where: { $0.version == version }) else {
            throw Error.attemptToAccessNonExistentVersion(version, fork)
        }
        return commit.content
    }
    
    public func store(_ commit: Commit<Resource>, in fork: Fork) throws {
        guard forkToResource[fork] != nil else {
            throw Error.attemptToAccessNonExistentFork(fork)
        }
        guard !forkToResource[fork]!.contains(where: { $0.version == commit.version }) else {
            throw Error.attemptToReplaceExistingVersion(commit.version, fork)
        }
        forkToResource[fork]!.append(commit)
    }
}

extension AtomicRepository: Codable where Resource: Codable {

    public func persist() throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: managedFileURL!)
    }
    
    public func load() throws {
        let data = try Data(contentsOf: managedFileURL!)
        let loadedRepo = try JSONDecoder().decode(Self.self, from: data)
        forkToResource = loadedRepo.forkToResource
    }
    
}
