#if canImport(CloudKit)
import CloudKit
import AsyncAlgorithms

private enum AssetRecordKey {
    case deleted
    case asset
    case numberOfParts
    case totalSize
    case assetPart(Int)
    
    var string: String {
        switch self {
        case .deleted:
            return "deleted"
        case .asset:
            return "asset"
        case .numberOfParts:
            return "numberOfParts"
        case .totalSize:
            return "totalSize"
        case .assetPart(let partNumber):
            return "asset_part\(partNumber)"
        }
    }
}

public struct AssetChange: Sendable {
    public let fileName: String
    public let initiatedLocally: Bool
}

/// A class that manages file assets with CloudKit synchronization.
///
/// This class handles the storage and synchronization of files using CloudKit. It automatically splits large files
/// into parts for storage, with a maximum total size of 250MB per asset. Files larger than this limit will be rejected.
///
/// The class maintains a local copy of all assets and synchronizes changes with CloudKit, ensuring that all devices
/// have access to the same set of files. It uses soft deletion to track removed assets while maintaining metadata.
///
/// The class can also operate in a local-only mode, which is useful for setting up assets while offline or when
/// CloudKit synchronization is not needed. When switching from local-only mode to CloudKit mode, all local files
/// will be automatically uploaded to CloudKit.
@available(iOS 17.0, tvOS 17.0, watchOS 10.0, macOS 14.0, *)
public final class CloudKitAssets: @unchecked Sendable {
    public enum Error: Swift.Error {
        case sourceIsNotAFile
        case assetAlreadyExists
        case assetNotFound
        case syncEngineNotReady
        case assetTooLarge
    }

    public enum Configuration {
        case local
        case cloudKit(container: CKContainer, zoneName: String, syncImmediately: Bool = true)
    }
    
    public let rootDirectory: URL
    public let configuration: Configuration

    private static let stateFileName = "_CloudKitAssets_State.json"
    private static let tempDirName = "_CloudKitAssets_Temp"
    private static let maxTotalSize: Int64 = 250 * 1024 * 1024 // 250MB in bytes

    public let recordType: CKRecord.RecordType = "ForkedAsset"
    
    private var engine: CKSyncEngine?
    private let stateURL: URL
    private let tempDirURL: URL
    private let lock = NSRecursiveLock()
    
    private typealias StreamID = UInt64
    private var nextStreamID: StreamID = 0
    private var continuations: [StreamID: AsyncStream<AssetChange>.Continuation] = [:]
    
    /// Initializes a new CloudKitAssets instance with the specified directory and configuration.
    /// If configuration is .local, the instance will operate in local-only mode.
    /// If configuration is .cloudKit, syncImmediately determines whether to start syncing right away.
    public init(rootDirectory: URL, configuration: Configuration) throws {
        self.rootDirectory = rootDirectory
        self.configuration = configuration
        self.stateURL = rootDirectory.appendingPathComponent(Self.stateFileName)
        self.tempDirURL = rootDirectory.appendingPathComponent(Self.tempDirName)
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        
        // Clean temp directory by removing and recreating it
        try? FileManager.default.removeItem(at: tempDirURL)
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
        
        if case .cloudKit(_, _, let syncImmediately) = configuration, syncImmediately {
            startSyncing()
        }
    }
     
    /// Starts the CloudKit sync engine, loading any existing state and creating the zone if needed.
    /// If this is the first sync (no state file exists), it will automatically add all local files to CloudKit.
    public func startSyncing() {
        guard engine == nil else { return }
        guard case .cloudKit(let container, let zoneName, _) = configuration else { return }
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        
        // Load state serialization
        let stateSerialization: CKSyncEngine.State.Serialization?
        let isFirstSync = !FileManager.default.fileExists(atPath: stateURL.path)
        
        if !isFirstSync,
           let data = try? Data(contentsOf: stateURL),
           let state = try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data) {
            stateSerialization = state
        } else {
            stateSerialization = nil
        }
        
        // Setup engine
        let configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: stateSerialization,
            delegate: self
        )
        engine = CKSyncEngine(configuration)
        
        // Create zone if it doesn't exist
        let zone = CKRecordZone(zoneID: zoneID)
        engine!.state.add(pendingDatabaseChanges: [.saveZone(zone)])
        
        // If this is first sync, add all local files
        if isFirstSync {
            uploadAllLocalFiles()
        }
    }
    
    private func uploadAllLocalFiles() {
        guard let engine = engine,
              case .cloudKit(_, let zoneName, _) = configuration else { return }
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        if let files = try? listAssets() {
            let recordIDs = files.map { fileURL in
                let fileName = fileURL.lastPathComponent
                return CKRecord.ID(recordName: fileName, zoneID: zoneID)
            }
            let recordChanges: [CKSyncEngine.PendingRecordZoneChange] = recordIDs.map { .saveRecord($0) }
            engine.state.add(pendingRecordZoneChanges: recordChanges)
        }
    }
    
    private func deleteStateFileIfLocalOnly() {
        if case .local = configuration {
            try? FileManager.default.removeItem(at: stateURL)
        }
    }
    
    /// Adds a file asset from the specified URL, optionally with a custom name.
    /// The file must be under 250MB in size.
    public func addAsset(at fileURL: URL, named fileName: String? = nil) throws {
        if case .cloudKit = configuration {
            guard engine != nil else {
                throw Error.syncEngineNotReady
            }
        }
        
        // Verify the source URL points to a file
        let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
        guard let isDirectory = resourceValues.isDirectory,
              !isDirectory else {
            throw Error.sourceIsNotAFile
        }
        
        // Check file size
        guard let fileSize = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64,
              fileSize <= Self.maxTotalSize else {
            throw Error.assetTooLarge
        }
        
        let sourceFileName = fileURL.lastPathComponent
        let targetFileName = fileName ?? sourceFileName
        let assetURL = rootDirectory.appendingPathComponent(targetFileName)
        
        // Check if asset already exists
        if FileManager.default.fileExists(atPath: assetURL.path) {
            throw Error.assetAlreadyExists
        }
        
        // Copy file to our directory
        try FileManager.default.copyItem(at: fileURL, to: assetURL)
        
        // Create metadata record
        if case .cloudKit(_, let zoneName, _) = configuration {
            let zoneID = CKRecordZone.ID(zoneName: zoneName)
            let recordID = CKRecord.ID(recordName: targetFileName, zoneID: zoneID)
            
            // Add to sync engine
            engine!.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        } else {
            deleteStateFileIfLocalOnly()
        }
        
        // Notify of local change
        addToChangeStreams(AssetChange(fileName: targetFileName, initiatedLocally: true))
    }
    
    /// Adds a data asset with the specified name.
    public func addAsset(data: Data, named fileName: String) throws {
        if case .cloudKit = configuration {
            guard engine != nil else {
                throw Error.syncEngineNotReady
            }
        }
        
        let assetURL = rootDirectory.appendingPathComponent(fileName)
        
        // Check if asset already exists
        if FileManager.default.fileExists(atPath: assetURL.path) {
            throw Error.assetAlreadyExists
        }
        
        // Write data to file
        try data.write(to: assetURL)
        
        // Create metadata record
        if case .cloudKit(_, let zoneName, _) = configuration {
            let zoneID = CKRecordZone.ID(zoneName: zoneName)
            let recordID = CKRecord.ID(recordName: fileName, zoneID: zoneID)
            
            // Add to sync engine
            engine!.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        } else {
            deleteStateFileIfLocalOnly()
        }
        
        // Notify of local change
        addToChangeStreams(AssetChange(fileName: fileName, initiatedLocally: true))
    }
    
    /// Deletes an asset by name, removing it locally and marking it as deleted in CloudKit.
    public func deleteAsset(named fileName: String) throws {
        if case .cloudKit = configuration {
            guard engine != nil else {
                throw Error.syncEngineNotReady
            }
        }
        
        let assetURL = rootDirectory.appendingPathComponent(fileName)
        
        // Create a record with deletion marker and clear all asset properties
        if case .cloudKit(_, let zoneName, _) = configuration {
            let zoneID = CKRecordZone.ID(zoneName: zoneName)
            let recordID = CKRecord.ID(recordName: fileName, zoneID: zoneID)
            let record = CKRecord(recordType: recordType, recordID: recordID)
            record[AssetRecordKey.deleted.string] = true
            record[AssetRecordKey.asset.string] = nil
            record[AssetRecordKey.numberOfParts.string] = nil
            record[AssetRecordKey.totalSize.string] = nil
            for partNumber in 1...CKRecord.maxParts {
                record[AssetRecordKey.assetPart(partNumber).string] = nil
            }
            
            // Add to sync engine
            engine!.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        } else {
            deleteStateFileIfLocalOnly()
        }
        
        // Delete local file
        try? FileManager.default.removeItem(at: assetURL)
        
        // Notify of local change
        addToChangeStreams(AssetChange(fileName: fileName, initiatedLocally: true))
    }
    
    /// Lists all assets in the root directory, excluding hidden files and system files.
    public func listAssets() throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(at: rootDirectory, includingPropertiesForKeys: [.isHiddenKey, .isDirectoryKey])
        return contents.filter { url in
            // Skip our state file and .DS_Store
            let fileName = url.lastPathComponent
            guard fileName != Self.stateFileName,
                  fileName != ".DS_Store" else {
                return false
            }
            
            // Skip hidden files and directories
            guard let resourceValues = try? url.resourceValues(forKeys: [.isHiddenKey, .isDirectoryKey]),
                  let isHidden = resourceValues.isHidden,
                  let isDirectory = resourceValues.isDirectory,
                  !isHidden,
                  !isDirectory else {
                return false
            }
            
            return true
        }
    }
    
    /// Returns the data for an asset with the specified name.
    public func data(forAssetNamed fileName: String) throws -> Data {
        let assetURL = rootDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: assetURL.path) else {
            throw Error.assetNotFound
        }
        return try Data(contentsOf: assetURL)
    }
}

@available(iOS 17.0, tvOS 17.0, watchOS 10.0, macOS 14.0, *)
extension CloudKitAssets {
    private func serialize<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
    
    /// Returns a stream of asset changes, including both local and remote modifications.
    public var changeStream: AsyncStream<AssetChange> {
        AsyncStream { continuation in
            serialize {
                let currentID = nextStreamID
                continuations[currentID] = continuation
                continuation.onTermination = { @Sendable [weak self] _ in
                    guard let self else { return }
                    serialize {
                        continuations[currentID] = nil
                    }
                }
                nextStreamID += 1
            }
        }
    }
    
    private func addToChangeStreams(_ change: AssetChange) {
        serialize {
            for continuation in continuations.values {
                continuation.yield(change)
            }
        }
    }
}

@available(iOS 17.0, tvOS 17.0, watchOS 10.0, macOS 14.0, *)
extension CloudKitAssets: CKSyncEngineDelegate {
    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let event):
            // Save state when it changes
            try? JSONEncoder().encode(event.stateSerialization).write(to: stateURL)
            
        case .accountChange(let event):
            switch event.changeType {
            case .signIn, .switchAccounts:
                // When signing in or switching accounts, remove the old state file
                // since it's specific to the previous account
                try? FileManager.default.removeItem(at: stateURL)
                
                // Upload all local files
                uploadAllLocalFiles()
            case .signOut:
                // When signing out, we keep both local files and CloudKit assets
                // This allows other devices to access the assets when they sign in
                // Remove the state file since it's specific to the previous account
                try? FileManager.default.removeItem(at: stateURL)
                break
            @unknown default:
                break
            }
            
        case .fetchedRecordZoneChanges(let event):
            for modification in event.modifications {
                let fileName = modification.record.recordID.recordName
                // Handle new, modified, or deleted asset
                if case .cloudKit(_, let zoneName, _) = configuration {
                    let zoneID = CKRecordZone.ID(zoneName: zoneName)
                    let recordID = CKRecord.ID(recordName: fileName, zoneID: zoneID)
                    if let asset = try? await engine?.database.record(for: recordID) {
                        let destinationURL = rootDirectory.appendingPathComponent(fileName)
                        try? asset.reconstructAsset(to: destinationURL)
                        addToChangeStreams(AssetChange(fileName: fileName, initiatedLocally: false))
                    }
                }
            }
            
        case .sentRecordZoneChanges(let event):
            // Clean up temp files for records that were successfully saved
            for recordSave in event.savedRecords {
                cleanupTempFilesForRecord(recordSave)
            }
            
        default:
            break
        }
    }
    
    /// Cleans up temporary files associated with a record after successful upload
    private func cleanupTempFilesForRecord(_ record: CKRecord) {
        // Check if this record has parts
        if let numberOfParts = record[AssetRecordKey.numberOfParts.string] as? Int {
            let fileName = record.recordID.recordName
            
            // Delete all part files for this record
            for partNumber in 1...numberOfParts {
                let partFileName = "\(fileName)_part\(partNumber)"
                let partURL = tempDirURL.appendingPathComponent(partFileName)
                try? FileManager.default.removeItem(at: partURL)
            }
        }
    }
    
    public func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pendingChanges = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pendingChanges) { [self] recordID in
            let fileName = recordID.recordName
            let assetURL = rootDirectory.appendingPathComponent(fileName)
            
            // Try to fetch existing record first
            let record = (try? await engine?.database.record(for: recordID)) ?? CKRecord(recordType: recordType, recordID: recordID)
            
            if FileManager.default.fileExists(atPath: assetURL.path) {
                try? record.addAsset(assetURL, tempDir: tempDirURL)
            } else {
                record[AssetRecordKey.deleted.string] = true
            }
            
            return record
        }
    }
}

@available(iOS 17.0, tvOS 17.0, watchOS 10.0, macOS 14.0, *)
extension CKRecord {
    static let maxPartSize: Int64 = 50 * 1024 * 1024 // 50MB in bytes
    static let maxParts = 5
    
    func addAsset(_ fileURL: URL, tempDir: URL) throws {
        // Get file size
        let fileSize = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 ?? 0
        
        // Clear any deletion marker
        self[AssetRecordKey.deleted.string] = false
        
        if fileSize ?? 0 <= Self.maxPartSize {
            // For small files, use the original asset field
            let asset = CKAsset(fileURL: fileURL)
            self[AssetRecordKey.asset.string] = asset
            
            // Clear any part properties that might exist from a previous version
            self[AssetRecordKey.numberOfParts.string] = nil
            self[AssetRecordKey.totalSize.string] = nil
            for partNumber in 1...Self.maxParts {
                self[AssetRecordKey.assetPart(partNumber).string] = nil
            }
        } else {
            // For large files, split into parts
            let numberOfParts = Swift.min(Self.maxParts, Int((fileSize! + Self.maxPartSize - 1) / Self.maxPartSize))
            
            // Clear the single asset property
            self[AssetRecordKey.asset.string] = nil
            
            // Clear any existing part properties beyond what we need
            for partNumber in (numberOfParts + 1)...Self.maxParts {
                self[AssetRecordKey.assetPart(partNumber).string] = nil
            }
            
            // Split file into parts using the provided temp directory
            if let fileHandle = try? FileHandle(forReadingFrom: fileURL) {
                for partNumber in 1...numberOfParts {
                    // Create a unique filename based on the source file's name
                    let fileName = fileURL.lastPathComponent
                    let partURL = tempDir.appendingPathComponent("\(fileName)_part\(partNumber)")
                    
                    if let partHandle = try? FileHandle(forWritingTo: partURL) {
                        // Read and write the part
                        let bytesToRead = Swift.min(Self.maxPartSize, fileSize! - Int64(partNumber - 1) * Self.maxPartSize)
                        if let data = try? fileHandle.read(upToCount: Int(bytesToRead)) {
                            try? partHandle.write(contentsOf: data)
                        }
                        try? partHandle.close()
                        
                        // Add the part to the record
                        let partAsset = CKAsset(fileURL: partURL)
                        self[AssetRecordKey.assetPart(partNumber).string] = partAsset
                    }
                }
                try? fileHandle.close()
            }
            
            // Add metadata about the parts
            self[AssetRecordKey.numberOfParts.string] = numberOfParts
            if let fileSize = fileSize {
                self[AssetRecordKey.totalSize.string] = fileSize
            }
        }
    }
    
    func reconstructAsset(to destinationURL: URL) throws {
        // Check if this record is marked for deletion
        if let isDeleted = self[AssetRecordKey.deleted.string] as? Bool, isDeleted {
            try? FileManager.default.removeItem(at: destinationURL)
            return
        }
        
        // Check if this is a split asset
        if let numberOfParts = self[AssetRecordKey.numberOfParts.string] as? Int {
            // Create a temporary directory for the parts
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            defer {
                // Clean up temp directory
                try? FileManager.default.removeItem(at: tempDir)
            }
            
            // Download all parts
            var partURLs: [URL] = []
            for partNumber in 1...numberOfParts {
                if let partAsset = self[AssetRecordKey.assetPart(partNumber).string] as? CKAsset,
                   let sourceURL = partAsset.fileURL {
                    let partURL = tempDir.appendingPathComponent("part\(partNumber)")
                    _ = try? FileManager.default.copyItem(at: sourceURL, to: partURL)
                    partURLs.append(partURL)
                }
            }
            
            // Combine parts into final file
            if let outputHandle = try? FileHandle(forWritingTo: destinationURL) {
                for partURL in partURLs {
                    var partHandle: FileHandle?
                    if let handle = try? FileHandle(forReadingFrom: partURL),
                       let data = try? handle.readToEnd() {
                        try? outputHandle.write(contentsOf: data)
                        partHandle = handle
                    }
                    try? partHandle?.close()
                }
                try? outputHandle.close()
            }
        } else if let assetReference = self[AssetRecordKey.asset.string] as? CKAsset,
                  let sourceURL = assetReference.fileURL {
            // Handle single asset (under 50MB)
            _ = try? FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }
    }
}

#endif
