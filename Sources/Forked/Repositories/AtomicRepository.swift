import Foundation

/// An atomic repository is one that is completely in memory.
/// If the `Resource` it contains conforms to `Codable`, the `AtomicRepository` is
/// also `Codable`, and can be converted to a serialized form and saved as a file.
/// Saving and loading are atomic, that is, the whole repository is loaded from file, and the whole
/// file is written to disk.
public final class AtomicRepository<Resource>: Repository {
    private var forkToResource: [Fork:[Commit<Resource>]] = [:]
    
    /// If nil, does not persist to disk. Otherwise will persist to the file at
    /// the URL whenver  `persist` is called.
    let fileURL: URL?
    
    public init(fileURL: URL?) throws {
        self.fileURL = fileURL
        
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        
        if let persistable = self as? (any Persistable) {
            try persistable.load()
        }
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

extension AtomicRepository: Persistable, Codable where Resource: Codable {

    public func persist() throws {
        guard let fileURL else { return }
        guard let codable = self as? Codable else {
            fatalError("AtomicRepository with fileURL non-nil must conform to Codable")
        }
        let data = try JSONEncoder().encode(codable)
        try data.write(to: fileURL)
    }
    
    public func load() throws {
        guard let fileURL else { return }
        guard self is Codable, Resource.self is Codable.Type else { return }
        let data = try Data(contentsOf: fileURL)
        let loadedRepo = try JSONDecoder().decode(Self.self, from: data)
        forkToResource = loadedRepo.forkToResource
    }
    
}
