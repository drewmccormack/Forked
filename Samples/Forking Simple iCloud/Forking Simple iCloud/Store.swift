import Forked
import ForkedCloudKit
import Foundation
import AsyncAlgorithms

extension Fork {
    static let ui = Fork(name: "ui")
}

struct Model: Codable {
    var text: String
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
            guard displayedText != model.text else { return }
            try! forkedText.update(.ui, with: Model(text: displayedText))
            try! forkedText.mergeIntoMain(from: .ui)
        }
    }

    init() throws {
        // Reads repo from disk if it exists, otherwise creates it anew
        repo = try AtomicRepository(fileURL: Self.repoFileURL)
        
        // Setup ForkedResource
        forkedText = try ForkedResource(repository: repo)
        if !forkedText.has(.ui) {
            try forkedText.create(.ui)
            try forkedText.update(.ui, with: Model(text: "Fork yeah!")) // First text in UI
        }
     
        // Setup CloudKitExchange
        cloudKitExchange = try .init(id: "ForkedRepo", forkedResource: forkedText)
        
        // Set displayed text to what is in the repo
        displayedText = try forkedText.resource(of: .ui)!.text
        
        // Setup streams to monitor changes
        setupStreams()
    }
    
    private func setupStreams() {
        // Monitor stream of updates to resource (eg remote sync changes)
        Task { [weak self, forkedText] in
            try! forkedText.mergeFromMain(into: .ui)
            for await change in forkedText.changeStream where change.fork == .main && change.mergingFork != .ui {
                guard let self else { return }
                try! forkedText.mergeFromMain(into: .ui)
                self.displayedText = model.text
            }
        }
        
        // Save following changes
        Task { [weak self, forkedText] in
            for await _ in forkedText.changeStream.debounce(for: .seconds(0.5)) {
                guard let self else { return }
                try! self.repo.persist()
            }
        }
    }
}
