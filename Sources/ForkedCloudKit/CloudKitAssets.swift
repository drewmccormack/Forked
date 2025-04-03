#if canImport(CloudKit)
import CloudKit
import AsyncAlgorithms

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
@available(iOS 17.0, tvOS 17.0, watchOS 10.0, macOS 14.0, *)
public final class CloudKitAssets: @unchecked Sendable {
    public enum Error: Swift.Error {
        case sourceIsNotAFile
        case assetAlreadyExists
        case assetNotFound
        case syncEngineNotReady
        case assetTooLarge
    }
    
    private static let stateFileName = "_CloudKitAssets_State.json"
    private static let maxTotalSize: Int64 = 250 * 1024 * 1024 // 250MB in bytes
    
    public let rootDirectory: URL
    public let cloudKitContainer: CKContainer
    public let zoneID: CKRecordZone.ID
    public let recordType: CKRecord.RecordType = "ForkedAsset"
    
    private var engine: CKSyncEngine?
    private let stateURL: URL
    private let lock = NSRecursiveLock()
    
    private typealias StreamID = UInt64
    private var nextStreamID: StreamID = 0
    private var continuations: [StreamID: AsyncStream<AssetChange>.Continuation] = [:]
    
    /// Initializes a new CloudKitAssets instance with the specified directory and zone.
    /// The sync engine starts immediately unless syncImmediately is passed in as false.
    public init(rootDirectory: URL, zoneName: String, cloudKitContainer: CKContainer = .default(), syncImmediately: Bool = true) throws {
        self.rootDirectory = rootDirectory
        self.cloudKitContainer = cloudKitContainer
        self.zoneID = CKRecordZone.ID(zoneName: zoneName)
        self.stateURL = rootDirectory.appendingPathComponent(Self.stateFileName)
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        
        if syncImmediately {
            startSyncing()
        }
    }
     
    /// Starts the CloudKit sync engine, loading any existing state and creating the zone if needed.
    public func startSyncing() {
        guard engine == nil else { return }
        
        // Load state serialization
        let stateSerialization: CKSyncEngine.State.Serialization?
        if let data = try? Data(contentsOf: stateURL),
           let state = try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data) {
            stateSerialization = state
        } else {
            stateSerialization = nil
        }
        
        // Setup engine
        let configuration = CKSyncEngine.Configuration(
            database: cloudKitContainer.privateCloudDatabase,
            stateSerialization: stateSerialization,
            delegate: self
        )
        engine = CKSyncEngine(configuration)
        
        // Create zone if it doesn't exist
        let zone = CKRecordZone(zoneID: zoneID)
        engine!.state.add(pendingDatabaseChanges: [.saveZone(zone)])
    }
    
    /// Adds a file asset from the specified URL, optionally with a custom name.
    /// The file must be under 250MB in size.
    public func addAsset(at fileURL: URL, named fileName: String? = nil) throws {
        guard let engine else {
            throw Error.syncEngineNotReady
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
        let recordID = CKRecord.ID(recordName: targetFileName, zoneID: zoneID)
        
        // Add to sync engine
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        
        // Notify of local change
        addToChangeStreams(AssetChange(fileName: targetFileName, initiatedLocally: true))
    }
    
    /// Adds a data asset with the specified name.
    public func addAsset(data: Data, named fileName: String) throws {
        guard let engine else {
            throw Error.syncEngineNotReady
        }
        
        let assetURL = rootDirectory.appendingPathComponent(fileName)
        
        // Check if asset already exists
        if FileManager.default.fileExists(atPath: assetURL.path) {
            throw Error.assetAlreadyExists
        }
        
        // Write data to file
        try data.write(to: assetURL)
        
        // Create metadata record
        let recordID = CKRecord.ID(recordName: fileName, zoneID: zoneID)
        
        // Add to sync engine
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        
        // Notify of local change
        addToChangeStreams(AssetChange(fileName: fileName, initiatedLocally: true))
    }
    
    /// Deletes an asset by name, removing it locally and marking it as deleted in CloudKit.
    public func deleteAsset(named fileName: String) throws {
        guard let engine else {
            throw Error.syncEngineNotReady
        }
        
        let assetURL = rootDirectory.appendingPathComponent(fileName)
        
        // Create a record with deletion marker and clear all asset properties
        let recordID = CKRecord.ID(recordName: fileName, zoneID: zoneID)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["deleted"] = true
        
        // Clear all asset-related properties
        record["asset"] = nil
        record["numberOfParts"] = nil
        record["totalSize"] = nil
        for partNumber in 1...CKRecord.maxParts {
            record["asset_part\(partNumber)"] = nil
        }
        
        // Add to sync engine
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        
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
        return try Data(contentsOf: assetURL, options: .mappedIfSafe)
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
                if let files = try? listAssets() {
                    for fileURL in files {
                        let fileName = fileURL.lastPathComponent
                        let recordID = CKRecord.ID(recordName: fileName, zoneID: zoneID)
                        engine?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
                    }
                }
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
                let recordID = CKRecord.ID(recordName: fileName, zoneID: zoneID)
                if let asset = try? await engine?.database.record(for: recordID) {
                    let destinationURL = rootDirectory.appendingPathComponent(fileName)
                    try? asset.reconstructAsset(to: destinationURL)
                    addToChangeStreams(AssetChange(fileName: fileName, initiatedLocally: false))
                }
            }
            
        case .sentRecordZoneChanges:
            // No need to do anything here - the records have already been saved
            break
            
        default:
            break
        }
    }
    
    public func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pendingChanges = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pendingChanges) { [self] recordID in
            let fileName = recordID.recordName
            let assetURL = rootDirectory.appendingPathComponent(fileName)
            
            let record = CKRecord(recordType: recordType, recordID: recordID)
            
            if FileManager.default.fileExists(atPath: assetURL.path) {
                try? record.addAsset(assetURL)
            } else {
                // Mark the record for deletion
                record["deleted"] = true
            }
            
            return record
        }
    }
}

@available(iOS 17.0, tvOS 17.0, watchOS 10.0, macOS 14.0, *)
extension CKRecord {
    static let maxPartSize: Int64 = 50 * 1024 * 1024 // 50MB in bytes
    static let maxParts = 5
    
    func addAsset(_ fileURL: URL) throws {
        // Get file size
        let fileSize = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 ?? 0
        
        // Clear any deletion marker
        self["deleted"] = false
        
        if fileSize ?? 0 <= Self.maxPartSize {
            // For small files, use the original asset field
            let asset = CKAsset(fileURL: fileURL)
            self["asset"] = asset
        } else {
            // For large files, split into parts
            let numberOfParts = Swift.min(Self.maxParts, Int((fileSize! + Self.maxPartSize - 1) / Self.maxPartSize))
            
            // Create a temporary directory for the parts
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            defer {
                // Clean up temp directory
                try? FileManager.default.removeItem(at: tempDir)
            }
            
            // Split file into parts
            if let fileHandle = try? FileHandle(forReadingFrom: fileURL) {
                for partNumber in 1...numberOfParts {
                    let partURL = tempDir.appendingPathComponent("part\(partNumber)")
                    if let partHandle = try? FileHandle(forWritingTo: partURL) {
                        // Read and write the part
                        let bytesToRead = Swift.min(Self.maxPartSize, fileSize! - Int64(partNumber - 1) * Self.maxPartSize)
                        if let data = try? fileHandle.read(upToCount: Int(bytesToRead)) {
                            try? partHandle.write(contentsOf: data)
                        }
                        try? partHandle.close()
                        
                        // Add the part to the record
                        let partAsset = CKAsset(fileURL: partURL)
                        self["asset_part\(partNumber)"] = partAsset
                    }
                }
                try? fileHandle.close()
            }
            
            // Add metadata about the parts
            self["numberOfParts"] = numberOfParts
            self["totalSize"] = fileSize
        }
    }
    
    func reconstructAsset(to destinationURL: URL) throws {
        // Check if this record is marked for deletion
        if self["deleted"] as? Bool == true {
            try? FileManager.default.removeItem(at: destinationURL)
            return
        }
        
        // Check if this is a split asset
        if let numberOfParts = self["numberOfParts"] as? Int {
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
                if let partAsset = self["asset_part\(partNumber)"] as? CKAsset,
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
        } else if let assetReference = self["asset"] as? CKAsset,
                  let sourceURL = assetReference.fileURL {
            // Handle single asset (under 50MB)
            _ = try? FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }
    }
}

#endif
