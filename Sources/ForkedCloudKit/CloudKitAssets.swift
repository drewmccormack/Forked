#if canImport(CloudKit)
import CloudKit

@available(iOS 17.0, tvOS 17.0, watchOS 10.0, macOS 14.0, *)
public final class CloudKitAssets: @unchecked Sendable {
    public enum Error: Swift.Error {
        case sourceIsNotAFile
    }
    
    private static let stateFileName = "_CloudKitAssets_State.json"
    
    public let rootDirectory: URL
    public let cloudKitContainer: CKContainer
    public let zoneID: CKRecordZone.ID
    public let recordType: CKRecord.RecordType = "ForkedAsset"
    
    private var engine: CKSyncEngine!
    private let stateURL: URL
    
    public init(rootDirectory: URL, zoneName: String, cloudKitContainer: CKContainer = .default()) throws {
        self.rootDirectory = rootDirectory
        self.cloudKitContainer = cloudKitContainer
        self.zoneID = CKRecordZone.ID(zoneName: zoneName)
        self.stateURL = rootDirectory.appendingPathComponent(Self.stateFileName)
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        
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
        engine.state.add(pendingDatabaseChanges: [.saveZone(zone)])
    }
    
    public func addAsset(at fileURL: URL, named fileName: String? = nil) throws {
        // Verify the source URL points to a file
        let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
        guard let isDirectory = resourceValues.isDirectory,
              !isDirectory else {
            throw Error.sourceIsNotAFile
        }
        
        let sourceFileName = fileURL.lastPathComponent
        let targetFileName = fileName ?? sourceFileName
        let assetURL = rootDirectory.appendingPathComponent(targetFileName)
        
        // Copy file to our directory
        try FileManager.default.copyItem(at: fileURL, to: assetURL)
        
        // Create metadata record
        let recordID = CKRecord.ID(recordName: targetFileName, zoneID: zoneID)
        
        // Add to sync engine
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
    }
    
    public func deleteAsset(named fileName: String) throws {
        let assetURL = rootDirectory.appendingPathComponent(fileName)
        
        // Delete from CloudKit
        let recordID = CKRecord.ID(recordName: fileName, zoneID: zoneID)
        engine.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
        
        // Delete local file
        try? FileManager.default.removeItem(at: assetURL)
    }
    
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
                        engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
                    }
                    try? await engine.sendChanges()
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
                // Handle new or modified asset
                let recordID = CKRecord.ID(recordName: fileName, zoneID: zoneID)
                if let asset = try? await engine.database.record(for: recordID) {
                    // Download the asset if needed
                    if let assetReference = asset["asset"] as? CKAsset,
                       let sourceURL = assetReference.fileURL {
                        let destinationURL = rootDirectory.appendingPathComponent(fileName)
                        _ = try? FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                    }
                }
            }
            
            for deletion in event.deletions {
                let fileName = deletion.recordID.recordName
                let assetURL = rootDirectory.appendingPathComponent(fileName)
                _ = try? FileManager.default.removeItem(at: assetURL)
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
            
            guard FileManager.default.fileExists(atPath: assetURL.path) else {
                return nil
            }
            
            let record = CKRecord(recordType: recordType, recordID: recordID)
            
            // Create CKAsset from file
            let asset = CKAsset(fileURL: assetURL)
            record["asset"] = asset
            
            return record
        }
    }
}
#endif 