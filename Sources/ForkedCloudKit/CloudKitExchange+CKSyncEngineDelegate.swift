import CloudKit
import os.log

@available(iOS 17.0, tvOS 17.0, watchOS 10.0, macOS 14.0, *)
extension CloudKitExchange: CKSyncEngineDelegate {
    
    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let event):
            do {
                // Careful to save resource first, so if there is a crash,
                // we continue from the previous state and don't lose anything
                syncState.stateSerialization = event.stateSerialization
                try forkedResource.performAtomically {
                    try forkedResource.persist()
                    try saveState()
                }
            } catch {
                Logger.exchange.error("Failed to save state: \(error)")
            }
        case .accountChange(let event):
            handleAccountChange(event)
        case .fetchedDatabaseChanges(let event):
            handleFetchedDatabaseChanges(event)
        case .fetchedRecordZoneChanges(let event):
            handleFetchedRecordZoneChanges(event)
        case .sentRecordZoneChanges(let event):
            handleSentRecordZoneChanges(event)
        case .sentDatabaseChanges:
            break
        case .willFetchChanges, .willFetchRecordZoneChanges, .didFetchRecordZoneChanges, .didFetchChanges, .willSendChanges, .didSendChanges:
            break
        @unknown default:
            Logger.exchange.info("Received unknown event: \(event)")
        }
    }
    
    public func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pendingChanges = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pendingChanges) { [self] recordID in
            forkedResource.performAtomically {
                guard recordID.recordName == id, recordFetchStatus != .uninitialized else {
                    return nil
                }
                
                do {
                    if let resourceValue = try resourceForUpload() {
                        let record = recordFetchStatus.record ?? CKRecord(recordType: recordType, recordID: recordID)
                        let data = try JSONEncoder().encode(resourceValue)
                        if data != record.encryptedValues[CKRecord.resourceDataKey] {
                            record.encryptedValues[CKRecord.resourceDataKey] = data
                            record["peerId"] = peerId
                            return record
                        } else {
                            syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                            return nil
                        }
                    } else {
                        syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                        return nil
                    }
                } catch {
                    Logger.exchange.error("Error while preparing batch of changes: \(error)")
                    return nil
                }
            }
        }
    }
    
}
