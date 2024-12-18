import Forked
import ForkedCloudKit
import Foundation
import AsyncAlgorithms

extension Fork {
    static let ui = Fork(name: "ui")
}

struct Model: Codable, Mergeable {
    var text: String
    func merged(withSubordinate other: Model, commonAncestor: Model) throws -> Model { self }
}

@MainActor
@Observable
class Store {
    private typealias RepoType = AtomicRepository<Model>
    private let repo: RepoType
    private let forkedText: ForkedResource<RepoType>
    private let cloudKitExchange: CloudKitExchange<RepoType>
    
    private static let repoDirURL: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    private static let repoFileURL: URL = repoDirURL.appendingPathComponent("ForkedRepo.json")
    private let fileManager = FileManager()
        
    /// Current value in .ui fork of repo
    private var model: Model {
        try! forkedText.resource(of: .ui)!
    }
    
    public var displayedText: String {
        didSet {
            guard displayedText != model.text, !suppressModelUpdates else { return }
            try! forkedText.update(.ui, with: Model(text: displayedText))
            try! forkedText.mergeIntoMain(from: .ui)
        }
    }
    private var suppressModelUpdates: Bool = false
    
    init() throws {
        // Reads repo from disk if it exists, otherwise creates it anew
        repo = try AtomicRepository(managedFileURL: Self.repoFileURL)
        
        // Setup ForkedResource
        forkedText = try ForkedResource(repository: repo)
        if !forkedText.has(.ui) {
            try forkedText.create(.ui)
            try forkedText.update(.ui, with: Model(text: "Fork yeah!")) // First text in UI
        }
     
        // Setup CloudKitExchange
        cloudKitExchange = try .init(id: "ForkedRepo", forkedResource: forkedText)
        
        // Set displayed text to what is in the repo
        suppressModelUpdates = true
        displayedText = try forkedText.resource(of: .ui)!.text
        suppressModelUpdates = false
        
        // Setup streams to monitor changes
        setupStreams()
    }
    
    /// Saves to disk
    public func save() {
        try! self.repo.persist()
    }
    
    private func setupStreams() {
        // Monitor stream of updates to resource (eg remote sync changes)
        // We listen to changes in the main fork, ignoring any merges from our own
        // fork (.ui), because we control those changes.
        Task { [weak self, forkedText] in
            try! forkedText.mergeFromMain(into: .ui)
            for await change in forkedText.changeStream where change.fork == .main && change.mergingFork != .ui {
                guard let self else { return }
                try! forkedText.mergeFromMain(into: .ui)
                suppressModelUpdates = true
                displayedText = model.text
                suppressModelUpdates = false
            }
        }
        
        // Save following changes, but only involving the UI fork,
        // because the CloudKitExchange handles persisting during sync.
        Task { [weak self, forkedText] in
            for await _ in forkedText.changeStream
                .filter({ $0.fork == .ui || $0.mergingFork == .ui })
                .debounce(for: .seconds(5)) {
                guard let self else { return }
                save()
            }
        }
    }
}
