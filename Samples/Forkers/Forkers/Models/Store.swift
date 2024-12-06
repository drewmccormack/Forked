import Foundation
import Forked
import ForkedCloudKit
import ForkedMerge
import ForkedModel
import SwiftUI
import AsyncAlgorithms

extension Fork {
    /// Holds currrently displayed forkers.
    /// We never directly update this fork. It just gets updated by merging
    /// from main. This is a truly data driven approach.
    static let ui = Fork(name: "ui")
    
    /// Any changes we make to the data are made in this fork.
    /// It is deliberately isolated from sync changes, so we don't get
    /// unexpected changes half way through editing.
    /// Keeping things in a separate fork also allows us to rollback
    /// changes by simply deleting the fork and creating it again.
    static let editing = Fork(name: "editing")
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
    
    // Observable array of forkers to display for SwiftUI
    // This is updated to be the same as the .ui fork.
    private(set) var displayedForkers: [Forker] = []
    
    // Forkers that are currently in the .ui fork.
    // This branch is used to update the displayedForkers for SwiftUI.
    // Any sync changes will automatically be merged in here, as well
    // as any editing commits. We use an AsyncStream to do the updates.
    private var uiForkers: [Forker] {
        try! forkedModel.resource(of: .ui)!.forkers
    }
    
    // Forkers that are currently in the .editing fork.
    // It is better to keep our mutable state in a separate fork, so that
    // we don't accidentally write over changes that come in from iCloud.
    // If we did this all in the .ui fork, it would be harder to manage
    // because we would need to prevent sync changes being merged in while
    // a Forker was being edited. This way, we know that the .editing fork
    // is completely isolated until we are ready to commit or rollback.
    private var editingForkers: [Forker] {
        get {
            return try! forkedModel.resource(of: .editing)!.forkers
        }
        set {
            var model = try! forkedModel.resource(of: .editing)!
            model.forkers = newValue
            try! forkedModel.update(.editing, with: model)
        }
    }
    
    init() throws {
        // Reads repo from disk if it exists, otherwise creates it anew
        repo = try AtomicRepository(managedFileURL: Self.repoFileURL)
        
        // Setup ForkedResource
        forkedModel = try ForkedResource(repository: repo)
        for fork: Fork in [.ui, .editing] {
            if !forkedModel.has(fork) {
                try forkedModel.create(fork)
                if fork == .ui {
                    // Start with empty array
                    try forkedModel.update(fork, with: Forkers(forkers: []))
                }
            }
        }
        
        // Get all the local forks in sync
        try forkedModel.syncMain(with: [.ui, .editing])
        
        // Setup CloudKitExchange
        cloudKitExchange = try .init(id: "ForkedForkers", forkedResource: forkedModel)
        
        // Set displayed forkers to what is in the repo
        displayedForkers = uiForkers
        
        // Save to disk
        save()
        
        // Setup streams to monitor changes
        setupStreams()
    }
    
}


// MARK: - Saving to Disk

extension Store {
    
    public func save() {
        try! self.repo.persist()
    }
    
}
 

// MARK: - Controlling Edits

extension Store {
    
    func startEdits() {
        try! forkedModel.syncMain(with: [.ui])
        try! forkedModel.mergeFromMain(into: .editing)
    }
    
    func commitEdits() {
        try! forkedModel.syncMain(with: [.editing])
    }
    
    func cancelEdits() {
        try! forkedModel.delete(.editing)
        try! forkedModel.create(.editing)
        try! forkedModel.syncMain(with: [.editing])
    }
    
}


// MARK: - Operations on Forkers

extension Store {
    
    func addForker(_ forker: Forker) {
        // Add the forker, but don't commit yet.
        // The user can still back out of the changes by
        // pressing cancel.
        editingForkers.append(forker)
    }
    
    func updateForker(_ forker: Forker) {
        // Stage the change, but don't commit until user presses save,
        // because user could cancel.
        if let index = editingForkers.firstIndex(where: { $0.id == forker.id }) {
            editingForkers[index] = forker
        }
    }
    
    func deleteForker(at indexSet: IndexSet) {
        // Deletes are committed immediately.
        editingForkers.remove(atOffsets: indexSet)
    }
    
    func moveForker(from source: IndexSet, to destination: Int) {
        editingForkers.move(fromOffsets: source, toOffset: destination)
    }
    
}


// MARK: - Streams for Monitoring Changes

extension Store {

    private func setupStreams() {
        // Monitor stream of updates to resource (e.g., remote sync changes, editing changes)
        Task { [weak self, forkedModel] in
            for await change in forkedModel.changeStream where change.fork == .main && change.mergingFork != .ui {
                guard let self else { return }
                try! forkedModel.mergeFromMain(into: .ui)
                displayedForkers = uiForkers
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
    
}
