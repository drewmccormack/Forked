import CloudKit
import SwiftUI
import AsyncAlgorithms
import Forked
public import os.log

public extension Logger {
    static let exchange = Logger(subsystem: "forked", category: "CloudKitExchange")
}

extension Fork {
    static let cloudKitUpload: Self = .init(name: "cloudKitUpload")
    static let cloudKitDownload: Self = .init(name: "cloudKitDownload")
}

extension CKRecord {
    static let resourceDataKey = "resourceData"
}

enum RecordFetchStatus: Equatable {
    case uninitialized
    case fetched(CKRecord)
    case doesNotExist
    
    var record: CKRecord? {
        guard case .fetched(let record) = self else { return nil }
        return record
    }
}

@available(iOS 17.0, tvOS 17.0, watchOS 10.0, macOS 14.0, *)
public final class CloudKitExchange<R: Repository>: @unchecked Sendable where R.Resource: Codable & Sendable {
    let id: String
    let forkedResource: ForkedResource<R>
    let cloudKitContainer: CKContainer
    let zoneID: CKRecordZone.ID = .init(zoneName: "Forked")
    let recordType: CKRecord.RecordType = "ForkedResource"
    var recordID: CKRecord.ID { CKRecord.ID(recordName: id, zoneID: zoneID) }
    
    internal private(set) var engine: CKSyncEngine!
    internal var recordFetchStatus: RecordFetchStatus = .uninitialized

    private let dataURL: URL
    
    internal struct SyncState: Codable {
        var stateSerialization: CKSyncEngine.State.Serialization?
    }
    internal var syncState: SyncState
    
    private let changeStream: ChangeStream
    private var monitorTask: Task<(), Never>!
    private var pollingTask: Task<(), Swift.Error>!
        
    public init(id: String, forkedResource: ForkedResource<R>, cloudKitContainer: CKContainer = .default()) throws {
        self.id = id
        self.forkedResource = forkedResource
        self.changeStream = forkedResource.changeStream
        self.cloudKitContainer = cloudKitContainer
        let dirURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appending(component: "CloudKitExchange")
        self.dataURL = dirURL
            .appending(component: id)
            .appendingPathExtension("json")

        if !FileManager.default.fileExists(atPath: dirURL.path()) {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }
        
        // Restore state
        let stateData = (try? Data(contentsOf: dataURL)) ?? Data()
        self.syncState = (try? JSONDecoder().decode(SyncState.self, from: stateData)) ?? SyncState()
        
        // Setup engine
        let configuration: CKSyncEngine.Configuration =
            .init(
                database: cloudKitContainer.privateCloudDatabase,
                stateSerialization: self.syncState.stateSerialization,
                delegate: self
            )
        engine = CKSyncEngine(configuration)

        // Create zone if it doesn't exist
        let zone = CKRecordZone(zoneID: zoneID)
        engine.state.add(pendingDatabaseChanges: [.saveZone(zone)])

        // Fork for sync
        try createForks()
        
        // Fetch the initial record using syncEngine's database
        Task { [self] in
            do {
                guard recordFetchStatus == .uninitialized else { return }
                let fetchedRecord = try await engine.database.record(for: recordID)
                Logger.exchange.info("Successfully fetched initial record from syncEngine's database.")
                recordFetchStatus = .fetched(fetchedRecord)
            } catch {
                recordFetchStatus = .doesNotExist
                Logger.exchange.error("Failed to fetch initial record from syncEngine's database: \(error)")
            }
        }
        
        // Monitor changes to main
        monitorTask = Task { [weak self, changeStream] in
            await self?.uploadMain()
            for await _ in changeStream
                .filter({
                    $0.fork == .main &&
                    ![.cloudKitDownload, .cloudKitUpload].contains($0.mergingFork)
                })
                .debounce(for: .seconds(1)) {
                guard let self else { break }
                Logger.exchange.info("Main fork changed, so will upload")
                await uploadMain()
            }
        }
        
        // Regularly check if an upload is needed,
        // in case the monitor task fails
        pollingTask = Task { [weak self] in
            while true {
                guard let self else { break }
                try Task.checkCancellation()
                try await Task.sleep(for: .seconds(60))
                Logger.exchange.info("Polling for new changes in cloud")
                try? await engine.fetchChanges()
                if let action = try? forkedResource.mergeIntoMain(from: .cloudKitDownload), action != .none {
                    Logger.exchange.info("Merged new changes into main from poll")
                }
                await uploadMain()
            }
        }
    }
    
    deinit {
        monitorTask.cancel()
        pollingTask.cancel()
    }
    
    func resourceForUpload() throws -> R.Resource? {
        try forkedResource.performAtomically {
            try forkedResource.mergeIntoMain(from: .cloudKitDownload)
            try forkedResource.mergeFromMain(into: .cloudKitUpload)
            return try forkedResource.resource(of: .cloudKitUpload)
        }
    }
    
    var needsUpload: Bool {
        get throws {
            try forkedResource.performAtomically {
                try forkedResource.hasUnmergedCommitsForMain(in: .cloudKitDownload) ||
                    forkedResource.hasUnmergedCommitsInMain(for: .cloudKitUpload)
            }
        }
    }
    
    private func enqueueUploadOfMainIfNeeded() {
        do {
            try forkedResource.performAtomically {
                try forkedResource.mergeIntoMain(from: .cloudKitDownload)
                if try needsUpload {
                    Logger.exchange.info("Main fork has unmerged changes. Uploading...")
                    let content = try forkedResource.content(of: .main)
                    if case .none = content {
                        engine.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
                    } else {
                        engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
                    }
                }
            }
        } catch {
            Logger.exchange.error("Failure monitoring changes: \(error)")
        }
    }
    
    private func uploadMain() async {
        enqueueUploadOfMainIfNeeded()
        try? await engine.sendChanges()
    }
    
    internal func saveState() throws {
        let data = try JSONEncoder().encode(syncState)
        try data.write(to: dataURL)
    }
}

@available(iOS 17.0, tvOS 17.0, watchOS 10.0, macOS 14.0, *)
internal extension CloudKitExchange {
    
    nonisolated func createForks() throws {
        for fork in [Fork.cloudKitUpload, .cloudKitDownload] where !forkedResource.has(fork) {
            try forkedResource.create(fork)
        }
    }
    
    nonisolated func removeForks() throws {
        for fork in [Fork.cloudKitUpload, .cloudKitDownload] where forkedResource.has(fork) {
            try forkedResource.mergeIntoMain(from: fork)
            try forkedResource.delete(fork)
        }
    }
    
}
