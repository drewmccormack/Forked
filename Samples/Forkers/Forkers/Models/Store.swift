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
    static let editingForker = Fork(name: "editing")
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
    
    /// Observable array of forkers to display for SwiftUI
    /// This is updated to be the same as the .ui fork.
    private(set) var displayedForkers: [Forker] = []
    
    /// Forkers that are currently in the .ui fork.
    /// This branch is used to update the displayedForkers for SwiftUI.
    /// Any sync changes will automatically be merged in here, as well
    /// as any editing commits. We use an AsyncStream to do the updates
    /// in a data driver way.
    private var uiForkers: [Forker] {
        get {
            try! forkedModel.resource(of: .ui)!.forkers
        }
        set {
            var model = try! forkedModel.resource(of: .ui)!
            model.forkers = newValue
            try! forkedModel.update(.ui, with: model)
            displayedForkers = uiForkers
        }
    }
    
    init() throws {
        // Reads repo from disk if it exists, otherwise creates it anew
        repo = try AtomicRepository(managedFileURL: Self.repoFileURL)
        
        // Setup ForkedResource
        forkedModel = try ForkedResource(repository: repo)
        for fork: Fork in [.ui, .editingForker] {
            if !forkedModel.has(fork) {
                try forkedModel.create(fork)
                if fork == .ui {
                    // Start with empty array
                    try forkedModel.update(fork, with: Forkers(forkers: []))
                }
            }
        }
        
        // Get all the local forks in sync
        try forkedModel.syncMain(with: [.ui, .editingForker])
        
        // Setup CloudKitExchange
        cloudKitExchange = try .init(id: "Forkers", forkedResource: forkedModel)
        
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
    
    /// Saves `ForkedReesource` to disk` with `Codable` serialization.`
    public func save() {
        try! self.repo.persist()
    }
    
}
 

// MARK: - Editing a Forker

extension Store {
    
    /// Prepare to put a Forker into edit mode. We create a new fork
    /// for this, so we can make edits in isolation from sync and other changes.
    /// We don't want changes appearing in our editing context while we edit.
    func prepareToEditForker() {
        try! forkedModel.delete(.editingForker)
        try! forkedModel.create(.editingForker)
        try! forkedModel.mergeFromMain(into: .editingForker)
    }
    
    /// Forkers that are currently in the .editing fork.
    /// We use a separate context for editing existing Forkers
    /// to prevent mixing in sync changes while we are editing.
    /// This way, we can make changes, and when user
    /// hits save or cancel, we can commit or rollback the changes.
    private var editingForkers: [Forker] {
        get {
            return try! forkedModel.resource(of: .editingForker)!.forkers
        }
        set {
            var model = try! forkedModel.resource(of: .editingForker)!
            model.forkers = newValue
            try! forkedModel.update(.editingForker, with: model)
        }
    }
    
    /// Returns the Forker in the editing context with the given ID.
    func editingForker(withId id: Forker.ID) -> Forker? {
        editingForkers.first(where: { $0.id == id })
    }
    
    func updateEditingForker(_ forker: Forker) {
        if let index = editingForkers.firstIndex(where: { $0.id == forker.id }) {
            editingForkers[index] = forker
        }
        try! forkedModel.syncMain(with: [.editingForker])
    }
    
}


// MARK: - Operations on Forkers

extension Store {
    
    func addForker(_ forker: Forker) {
        uiForkers.append(forker)
        commitUIChanges()
    }
    
    func deleteForker(at indexSet: IndexSet) {
        uiForkers.remove(atOffsets: indexSet)
        commitUIChanges()
    }
    
    func moveForker(from source: IndexSet, to destination: Int) {
        uiForkers.move(fromOffsets: source, toOffset: destination)
        commitUIChanges()
    }
    
    private func commitUIChanges() {
        try! forkedModel.mergeIntoMain(from: .ui)
    }
    
}


// MARK: - Streams for Monitoring Changes

extension Store {

    /// We setup a few streams to monitor changes in the data.
    /// One is to make sure that the .ui fork gets changes merged in from main
    /// whenever some other fork merges (eg editing fork, cloudkit fork).
    /// Another stream monitors any change involving the .ui fork, and
    /// schedules a save.
    private func setupStreams() {
        // Monitor stream of updates (e.g., remote sync changes, editing changes)
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
