import Foundation
import Forked
import ForkedCloudKit
import ForkedMerge
import ForkedModel
import SwiftUI
import AsyncAlgorithms

extension Fork {
    static let ui = Fork(name: "ui")
}

@ForkedModel
struct Forkers: Codable {
    @Merged var forkers: [Forker] = []
}

@MainActor
@Observable
class Store {
    private typealias RepoType = AtomicRepository<Forkers>
    private let repo: RepoType
    private let forkedModel: ForkedResource<RepoType>
    private let cloudKitExchange: CloudKitExchange<RepoType>
    
    private static let repoDirURL: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    private static let repoFileURL: URL = repoDirURL.appendingPathComponent("Forkers.json")
    
    private var storedForkers: [Forker] {
        get {
            return try! forkedModel.resource(of: .ui)!.forkers
        }
        set {
            var model = try! forkedModel.resource(of: .ui)!
            model.forkers = newValue
            try! forkedModel.update(.ui, with: model)
            self.displayedForkers = newValue
            try! forkedModel.mergeIntoMain(from: .ui) // Merge to main so it uploads
        }
    }
    
    private(set) var displayedForkers: [Forker] = []

    init() throws {
        // Reads repo from disk if it exists, otherwise creates it anew
        repo = try AtomicRepository(managedFileURL: Self.repoFileURL)
        
        // Setup ForkedResource
        var shouldSave = false
        forkedModel = try ForkedResource(repository: repo)
        if !forkedModel.has(.ui) {
            try forkedModel.create(.ui)
            try forkedModel.update(.ui, with: Forkers(forkers: [])) // Initialize with empty list
            shouldSave = true
        }
        
        // Setup CloudKitExchange
        cloudKitExchange = try .init(id: "ForkedForkers", forkedResource: forkedModel)
        
        // Set displayed forkers to what is in the repo
        displayedForkers = storedForkers
        
        // Setup streams to monitor changes
        setupStreams()
        
        // Save if we initialized the repo
        if shouldSave {
            save()
        }
    }
    
    private func setupStreams() {
        // Monitor stream of updates to resource (e.g., remote sync changes)
        Task { [weak self, forkedModel] in
            try! forkedModel.mergeFromMain(into: .ui)
            for await change in forkedModel.changeStream where change.fork == .main && change.mergingFork != .ui {
                guard let self else { return }
                try! forkedModel.mergeFromMain(into: .ui)
                displayedForkers = storedForkers
            }
        }
        
        // Save following changes, but only involving the UI fork,
        // because the CloudKitExchange handles persisting during sync.
        Task { [weak self, forkedModel] in
            for await _ in forkedModel.changeStream
                .filter({ $0.fork == .ui || $0.mergingFork == .ui })
                .debounce(for: .seconds(5)) {
                guard let self else { return }
                save()
            }
        }
    }
    
    public func save() {
        try! self.repo.persist()
    }
    
    func addForker(_ forker: Forker) {
        storedForkers.append(forker)
        save()
    }
    
    func updateForker(_ forker: Forker) {
        if let index = storedForkers.firstIndex(where: { $0.id == forker.id }) {
            storedForkers[index] = forker
        }
        save()
    }
    
    func deleteForker(at indexSet: IndexSet) {
        storedForkers.remove(atOffsets: indexSet)
        save()
    }
    
    func moveForker(from source: IndexSet, to destination: Int) {
        storedForkers.move(fromOffsets: source, toOffset: destination)
        save()
    }
}
