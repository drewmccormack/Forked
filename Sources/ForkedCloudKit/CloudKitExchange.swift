#if canImport(CloudKit)
import CloudKit
import SwiftUI
import AsyncAlgorithms
import Forked
public import os.log

public extension Logger {
    static let exchange = Logger(subsystem: "forked", category: "CloudKitExchange")
}

extension Fork {
    /// Represents the last known state of the resource on the cloud.
    static let cloudKit: Self = .init(name: "cloudKit")
    
    /// Used as temporary storage for uploading data. It's a staging area. We never merge it.
    /// We have this, because we don't want to update .cloudKit before we know that the upload
    /// definitely took place.
    static let uploadingToCloudKit: Self = .init(name: "uploadingToCloudKit")
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

public enum Error: Swift.Error {
    case unknownVersionEncountered(version: Int, type: String)
    case noDataFound
}

@available(iOS 17.0, tvOS 17.0, watchOS 10.0, macOS 14.0, *)
public final class CloudKitExchange<R: Repository>: @unchecked Sendable where R.Resource: Codable & Sendable & Mergeable & VersionedModel {
    public let id: String
    public let forkedResource: ForkedResource<R>
    public let cloudKitContainer: CKContainer
    public let zoneID: CKRecordZone.ID = .init(zoneName: "Forked")
    public let recordType: CKRecord.RecordType = "ForkedResource"
    public var recordID: CKRecord.ID { CKRecord.ID(recordName: id, zoneID: zoneID) }
    
    /// An exchange can terminate when an unknown model is encountered.
    /// The user should upgrade to continue.
    public private(set) var exchangeTerminatedDueToUnknownModelVersion: Bool = false
    
    /// This is called if an unknown model version is downloaded. It means this copy
    /// of the app is out-of-date and the user should be told to update. The exchange
    /// will stop trying to merge downloaded data to prevent data loss, and uploads
    /// will also stop as a result.
    internal let unknownModelVersionHandler: (Error) -> Void
    
    internal private(set) var engine: CKSyncEngine!
    internal var recordFetchStatus: RecordFetchStatus = .uninitialized

    private let dataURL: URL
    public let peerId: String
    
    internal struct SyncState: Codable {
        var stateSerialization: CKSyncEngine.State.Serialization?
    }
    internal var syncState: SyncState
    
    private let changeStream: ChangeStream
    private var monitorTask: Task<(), Never>?
    private var pollingTask: Task<(), Swift.Error>?
        
    public init(id: String, forkedResource: ForkedResource<R>, cloudKitContainer: CKContainer = .default(), unknownModelVersionHandler: @escaping (Error) -> Void) throws {
        self.id = id
        self.forkedResource = forkedResource
        self.changeStream = forkedResource.changeStream
        self.cloudKitContainer = cloudKitContainer
        self.unknownModelVersionHandler = unknownModelVersionHandler
        let dirURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appending(component: "CloudKitExchange")
        self.dataURL = dirURL
            .appending(component: id)
            .appendingPathExtension("json")
        
        // Create directory in Application Support if it doesn't exist
        if !FileManager.default.fileExists(atPath: dirURL.path()) {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }
        
        // Setup peerId. This allows us to skip changes from this device.
        var peerIdURL = dirURL.appendingPathComponent("PeerId_\(id).txt")
        if FileManager.default.fileExists(atPath: peerIdURL.path), let idRead = try? String(contentsOf: peerIdURL, encoding: .utf8) {
            self.peerId = idRead
        } else {
            let newPeerId = UUID().uuidString
            try newPeerId.write(to: peerIdURL, atomically: true, encoding: .utf8)
            self.peerId = newPeerId
            var res = URLResourceValues()
            res.isExcludedFromBackup = true
            try peerIdURL.setResourceValues(res)
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

        // Forks for sync
        try createForks()
        
        // Fetch the initial record using syncEngine's database
        Task { [self] in
            do {
                let fetchedRecord = try await engine.database.record(for: recordID)
                forkedResource.performAtomically {
                    guard recordFetchStatus == .uninitialized else { return }
                    recordFetchStatus = .fetched(fetchedRecord)
                    Logger.exchange.info("Successfully fetched initial record from syncEngine's database.")
                }
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
                    .cloudKit != $0.mergingFork
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
                try  mergeIntoMainFromCloudKitFork()
                await uploadMain()
            }
        }
    }
    
    deinit {
        monitorTask?.cancel()
        pollingTask?.cancel()
    }
    
    func resourceForUpload() throws -> R.Resource? {
        try forkedResource.performAtomically {
            try mergeIntoMainFromCloudKitFork()
            return try forkedResource.resource(of: .main)
        }
    }
    
    internal func mergeIntoMainFromCloudKitFork() throws {
        try forkedResource.performAtomically {
            guard let value = try forkedResource.value(in: .cloudKit) else { return }
            guard value.canLoadModelVersion else {
                let error = Error.unknownVersionEncountered(version: value.modelVersion ?? 0, type: String(describing: type(of: value)))
                stopExchangingDueToUnknownModelVersion(with: error)
                throw error
            }
            _ = try forkedResource.mergeIntoMain(from: .cloudKit)
        }
    }
    
    private func stopExchangingDueToUnknownModelVersion(with error: Error) {
        guard !exchangeTerminatedDueToUnknownModelVersion else { return }
        exchangeTerminatedDueToUnknownModelVersion = true
        monitorTask?.cancel()
        pollingTask?.cancel()
        unknownModelVersionHandler(error)
    }
    
    private func enqueueUploadOfMainIfNeeded() {
        do {
            try forkedResource.performAtomically {
                try mergeIntoMainFromCloudKitFork()
                if try forkedResource.hasUnmergedCommitsInMain(for: .cloudKit) {
                    let cloudKitContent = try forkedResource.content(of: .cloudKit)
                    let mainContent = try forkedResource.content(of: .main)
                    guard cloudKitContent != mainContent else { return }
                    
                    Logger.exchange.info("Main fork has unmerged changes. Uploading...")
                    if case .none = mainContent {
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
        for fork in [Fork.cloudKit, Fork.uploadingToCloudKit] where !forkedResource.has(fork) {
            try forkedResource.create(fork)
        }
    }
    
    nonisolated func removeForks() throws {
        try? mergeIntoMainFromCloudKitFork()
        try forkedResource.delete(.cloudKit)
        try forkedResource.delete(.uploadingToCloudKit)
    }
    
    internal func createRecordWithData(_ data: Data, recordID: CKRecord.ID) throws -> CKRecord {
        let record = CKRecord(recordType: recordType, recordID: recordID)
        
        if data.count <= CKRecord.maxEncryptedDataSize {
            // For small data, use encrypted values
            record.encryptedValues[CKRecord.resourceDataKey] = data
        } else {
            // For large data, create a temporary file and use CKAsset
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try data.write(to: tempURL)
            let asset = CKAsset(fileURL: tempURL)
            record[CKRecord.largeDataKey] = asset
            
            // Clean up temp file after asset is created
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        record["peerId"] = peerId
        return record
    }
}

@available(iOS 17.0, tvOS 17.0, watchOS 10.0, macOS 14.0, *)
extension CKRecord {
    static let resourceDataKey = "resourceData"
    static let largeDataKey = "largeData"
    static let maxEncryptedDataSize = 1024 * 1024 // 1MB
    
    func updateRecord(withResourceData data: Data, peerId: String) throws {
        if data.count <= Self.maxEncryptedDataSize {
            // For small data, use encrypted values
            encryptedValues[Self.resourceDataKey] = data
            self[Self.largeDataKey] = nil
        } else {
            // For large data, create a temporary file and use CKAsset
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try data.write(to: tempURL)
            let asset = CKAsset(fileURL: tempURL)
            self[Self.largeDataKey] = asset
            encryptedValues[Self.resourceDataKey] = nil
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        self["peerId"] = peerId
    }
    
    func extractResourceData() throws -> Data {
        if let data = encryptedValues[Self.resourceDataKey] as? Data {
            return data
        } else if let asset = self[Self.largeDataKey] as? CKAsset,
           let fileURL = asset.fileURL {
            return try Data(contentsOf: fileURL)
        } else {
            throw Error.noDataFound
        }
    }
}
#endif

