import Foundation
import Testing
@testable import Forked

struct FileRepositoryTests {

    let testDirectoryURL = URL(fileURLWithPath: "/tmp/repository")

    @Test func savingBasicFileRepository() throws {
        try? FileManager.default.removeItem(at: testDirectoryURL)
        let repo = try FileRepository(rootDirectory: testDirectoryURL)
        #expect(repo.forks.isEmpty)
        let fork = Fork("main")
        let commit = Commit(version: Version("v1"), content: "Hello, Forked!".data(using: .utf8)!)
        try repo.create(fork, withInitialCommit: commit)
        #expect(repo.forks == [fork])
        let retrievedContent = try repo.content(of: fork, at: commit.version)
        let retrievedString = String(data: retrievedContent, encoding: .utf8)
        #expect(retrievedString == "Hello, Forked!")
    }

    @Test func savingFileRepositoryWithChanges() throws {
        try? FileManager.default.removeItem(at: testDirectoryURL)
        let repo = try FileRepository(rootDirectory: testDirectoryURL)
        let fork = Fork("main")
        let commit1 = Commit(version: Version("v1"), content: "First commit".data(using: .utf8)!)
        let commit2 = Commit(version: Version("v2"), content: "Second commit".data(using: .utf8)!)
        try repo.create(fork, withInitialCommit: commit1)
        try repo.store(commit2, in: fork)
        let versions = try repo.versions(storedIn: fork)
        #expect(versions.count == 2)
        let retrievedContent = try repo.content(of: fork, at: commit2.version)
        let retrievedString = String(data: retrievedContent, encoding: .utf8)
        #expect(retrievedString == "Second commit")
    }

    @Test func deletingFork() throws {
        try? FileManager.default.removeItem(at: testDirectoryURL)
        let repo = try FileRepository(rootDirectory: testDirectoryURL)
        let fork = Fork("main")
        let commit = Commit(version: Version("v1"), content: "Initial commit".data(using: .utf8)!)
        try repo.create(fork, withInitialCommit: commit)
        #expect(repo.forks.contains(fork))
        try repo.delete(fork)
        #expect(repo.forks.isEmpty)
    }

    @Test func deletingCommit() throws {
        try? FileManager.default.removeItem(at: testDirectoryURL)
        let repo = try FileRepository(rootDirectory: testDirectoryURL)
        let fork = Fork("main")
        let commit1 = Commit(version: Version("v1"), content: "First commit".data(using: .utf8)!)
        let commit2 = Commit(version: Version("v2"), content: "Second commit".data(using: .utf8)!)
        try repo.create(fork, withInitialCommit: commit1)
        try repo.store(commit2, in: fork)
        let versions = try repo.versions(storedIn: fork)
        #expect(versions.count == 2)
        try repo.removeCommit(at: commit1.version, from: fork)
        let versionsAfterDeletion = try repo.versions(storedIn: fork)
        #expect(versionsAfterDeletion.count == 1)
        #expect(versionsAfterDeletion.first?.id == commit2.version.id)
    }
}