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

private enum ResourceRecordKey {
    case resourceData
    case largeData
    case peerId
    
    var string: String {
        switch self {
        case .resourceData:
            return "resourceData"
        case .largeData:
            return "largeData"
        case .peerId:
            return "peerId"
        }
    }
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
    internal let tempDirURL: URL
    public let peerId: String
    
    // Constants
    private let stateFileName = "CloudKitExchange_State.json"
    private let tempDirName = "_CloudKitExchange_Temp"
    
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
        self.tempDirURL = dirURL
            .appendingPathComponent(tempDirName)
        
        // Create directory in Application Support if it doesn't exist
        if !FileManager.default.fileExists(atPath: dirURL.path()) {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }
        
        // Create temp directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: tempDirURL.path()) {
            try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
        }
        
        // Clean up the specific temp file for this exchange if it exists
        let tempFileURL = tempDirURL.appendingPathComponent(id)
        try? FileManager.default.removeItem(at: tempFileURL)
        
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
                    update(withDownloadedRecord: fetchedRecord)
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
        guard recordFetchStatus != .uninitialized else { return }
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
    
    /// Cleans up temporary files associated with a record after successful upload
    internal func cleanupTempFilesForRecord(_ record: CKRecord) {
        // After successful upload to CloudKit, we can clean up the temporary file
        // used for the CKAsset. Since we're using recordID as the filename, it's easy to identify.
        if record[ResourceRecordKey.largeData.string] != nil {
            let fileName = record.recordID.recordName
            let fileURL = tempDirURL.appendingPathComponent(fileName)
            
            if FileManager.default.fileExists(atPath: fileURL.path()) {
                try? FileManager.default.removeItem(at: fileURL)
                Logger.exchange.info("Cleaned up temporary asset file: \(fileName)")
            }
        }
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
    
    func createRecordWithData(_ data: Data, recordID: CKRecord.ID) throws -> CKRecord {
        let record = CKRecord(recordType: recordType, recordID: recordID)
        
        try record.update(withResourceData: data, peerId: peerId, tempDir: tempDirURL)
        return record
    }
}

@available(iOS 17.0, tvOS 17.0, watchOS 10.0, macOS 14.0, *)
extension CKRecord {
    static let maxEncryptedDataSize = 1024 * 1024 // 1MB
    
    func update(withResourceData data: Data, peerId: String, tempDir: URL) throws {
        if data.count <= Self.maxEncryptedDataSize {
            // For small data, use encrypted values
            encryptedValues[ResourceRecordKey.resourceData.string] = data
            self[ResourceRecordKey.largeData.string] = nil
        } else {
            // For large data, create a file in the temp directory using recordID as the filename
            let fileName = recordID.recordName
            let fileURL = tempDir.appendingPathComponent(fileName)
            try data.write(to: fileURL)
            
            let asset = CKAsset(fileURL: fileURL)
            self[ResourceRecordKey.largeData.string] = asset
            encryptedValues[ResourceRecordKey.resourceData.string] = nil
        }
        
        self[ResourceRecordKey.peerId.string] = peerId
    }
    
    func extractResourceData() throws -> Data {
        if let data = encryptedValues[ResourceRecordKey.resourceData.string] as? Data {
            return data
        } else if let asset = self[ResourceRecordKey.largeData.string] as? CKAsset,
           let fileURL = asset.fileURL {
            return try Data(contentsOf: fileURL)
        } else {
            throw Error.noDataFound
        }
    }
}
#endif

