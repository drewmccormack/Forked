#if canImport(CloudKit)
import CloudKit
import Forked
import os.log

@available(iOS 17.0, tvOS 17.0, watchOS 10.0, macOS 14.0, *)
extension CloudKitExchange {
    
    func handleAccountChange(_ event: CKSyncEngine.Event.AccountChange) {
        do {
            try forkedResource.performAtomically {
                switch event.changeType {
                case .signIn, .switchAccounts:
                    try removeForks()
                    try createForks()
                case .signOut:
                    try removeForks()
                @unknown default:
                    Logger.exchange.log("Unknown account change type: \(event)")
                }
            }
        } catch {
            Logger.exchange.error("Failure during handling of account change: \(error)")
        }
    }
    
    func handleFetchedDatabaseChanges(_ event: CKSyncEngine.Event.FetchedDatabaseChanges) {
        for deletion in event.deletions {
            switch deletion.zoneID.zoneName {
            case zoneID.zoneName:
                do {
                    try removeForks()
                } catch {
                    Logger.exchange.error("Failed to delete content when zone removed: \(error)")
                }
            default:
                Logger.exchange.info("Received deletion for unknown zone: \(deletion.zoneID)")
            }
        }
        Logger.exchange.info("Fetched database changes")
    }
    
    func handleFetchedRecordZoneChanges(_ event: CKSyncEngine.Event.FetchedRecordZoneChanges) {
        Logger.exchange.info("Handling fetched record zone changes")
    
        // Skip if the modification came from this device.
        // If we import it onto the .cloudKit fork, it will be merged into main
        // and then become the ancestor. When data from another device appears
        // it will rollback anything unchanged from the other device, because
        // it will be different to the ancestor, and will seem like a recent change.
        for modification in event.modifications {
            let id = modification.record.recordID.recordName
            guard self.id == id else { continue }
            
            // Check if the record has a peerId and if it matches the current device
            if let recordPeerId = modification.record["peerId"] as? String,
               recordPeerId == peerId {
                recordFetchStatus = .fetched(modification.record)
                Logger.exchange.info("Received record from our device, updating record reference only")
                continue
            }
            
            update(withDownloadedRecord: modification.record)
            Logger.exchange.info("Updated with record: \(modification.record.recordID.recordName)")
        }
        
        for deletion in event.deletions {
            let id = deletion.recordID.recordName
            guard self.id == id else { continue }
            do {
                try forkedResource.removeContent(from: .cloudKit)
                try mergeIntoMainFromCloudKitFork()
                recordFetchStatus = .doesNotExist
            } catch {
                Logger.exchange.error("Failed to update resource with downloaded data: \(error)")
            }
            Logger.exchange.info("Updated for deletion of record: \(id)")
        }
        
        Logger.exchange.info("Fetched record zone changes")
    }
    
    func handleSentRecordZoneChanges(_ event: CKSyncEngine.Event.SentRecordZoneChanges) {
        for recordSave in event.savedRecords {
            let id = recordSave.recordID.recordName
            guard self.id == id else { continue }
            Logger.exchange.info("Saved record to CloudKit: \(id)")

            // We have the newly uploaded data. In the meantime,
            // .main may have new changes, so we can't just merge.
            // We use a restart instead. This sets our uploaded data
            // as the new ancestor.
            do {
                try forkedResource.performAtomically {
                    if let uploading = try forkedResource.resource(of: .uploadingToCloudKit) {
                        try forkedResource.restart(.cloudKit, with: uploading)
                        try forkedResource.removeContent(from: .uploadingToCloudKit)
                    } else {
                        Logger.exchange.error("Attempt to handle uploaded record, but no uploading resource found: \(recordSave.recordID.recordName)")
                    }
                }
            } catch {
                Logger.exchange.error("Exception handling sent record zone: \(error)")
            }
        }
        
        for recordDelete in event.deletedRecordIDs {
            let id = recordDelete.recordName
            guard self.id == id else { continue }
            Logger.exchange.info("Deleted record in CloudKit: \(id)")
            
            do {
                try forkedResource.performAtomically {
                    try forkedResource.removeContent(from: .cloudKit)
                    try forkedResource.removeContent(from: .uploadingToCloudKit)
                }
            } catch {
                Logger.exchange.error("Exception handling sent record zone: \(error)")
            }
        }
        
        for failedRecordSave in event.failedRecordSaves {
            let failedRecord = failedRecordSave.record
            let id = failedRecord.recordID.recordName
            guard self.id == id else { continue }
            
            Logger.exchange.warning("Failed record save: \(failedRecordSave.error)")
            
            switch failedRecordSave.error.code {
            case .serverRecordChanged:
                guard let serverRecord = failedRecordSave.error.serverRecord else {
                    Logger.exchange.error("No server record for conflict \(failedRecordSave.error)")
                    continue
                }
                update(withDownloadedRecord: serverRecord)
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(failedRecord.recordID)])
                Logger.exchange.info("Server record was changed, so updated and will try again")
            case .zoneNotFound:
                do {
                    try removeForks()
                    try createForks()
                    let zone = CKRecordZone(zoneID: failedRecord.recordID.zoneID)
                    engine.state.add(pendingDatabaseChanges: [.saveZone(zone)])
                    engine.state.add(pendingRecordZoneChanges: [.saveRecord(failedRecord.recordID)])
                } catch {
                    Logger.exchange.error("Failed to recover from missing zone: \(error)")
                }
            case .unknownItem:
                // May be deleted by other device. Let that deletion propagate naturally.
                Logger.exchange.error("Unknown item error following upload. Ignoring: \(failedRecordSave.error)")
            case .assetFileNotFound:
                // The temporary file was cleaned up before upload. Re-enqueue the upload.
                Logger.exchange.info("Asset file not found, re-enqueueing upload")
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(failedRecord.recordID)])
            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable, .notAuthenticated, .operationCancelled:
                Logger.exchange.debug("Retryable error saving \(failedRecord.recordID): \(failedRecordSave.error)")
            default:
                Logger.exchange.fault("Unknown error saving record \(failedRecord.recordID): \(failedRecordSave.error)")
            }
        }
    }
    
    func update(withDownloadedRecord record: CKRecord) {
        let id = record.recordID.recordName
        guard self.id == id else { return }
        
        do {
            let data = try record.extractResourceData()
            try forkedResource.performAtomically {
                recordFetchStatus = .fetched(record)
                let resource = try JSONDecoder().decode(R.Resource.self, from: data)
                let newContent: CommitContent = .resource(resource)
                let existingContent = try forkedResource.content(of: .cloudKit)
                guard existingContent != newContent else { return }
                try forkedResource.update(.cloudKit, with: resource)
                try mergeIntoMainFromCloudKitFork()
                Logger.exchange.info("Updated cloudKitDownload with downloaded data, and merged into main")
            }
        } catch {
            Logger.exchange.error("Failed to update resource with downloaded data: \(error)")
        }
    }
    
    
}
#endif
