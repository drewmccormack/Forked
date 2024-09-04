//
//  CloudKitExchange.swift
//  Forked
//
//  Created by Drew McCormack on 14/08/2024.
//
import CloudKit
import SwiftUI
import Forked
import Semaphore
import os.log

extension Logger {
    static let exchange = Logger(subsystem: "forked", category: "CloudKitExchange")
}

extension Fork {
    static let cloudKit: Self = .init(name: "cloudKit")
}

public protocol CloudKitExchangeDelegate: AnyObject {
    func exchangeDidUpdateAllForks<R>(_ exchange: CloudKitExchange<R>)
    func exchangeDidUpdateMainFork<R>(_ exchange: CloudKitExchange<R>)
}

extension CKRecord {
    static let resourceDataKey = "resourceData"
}

@available(iOS 17.0, tvOS 17.0, watchOS 9.0, macOS 14.0, *)
public actor CloudKitExchange<R: Repository> where R.Resource: Codable {
    let id: String
    let forkedResource: ForkedResource<R>
    let cloudKitContainer: CKContainer
    let zoneID: CKRecordZone.ID = .init(zoneName: "Forked")
    var recordID: CKRecord.ID { CKRecord.ID(recordName: id, zoneID: zoneID) }
    weak var delegate: CloudKitExchangeDelegate?
    
    internal var engine: CKSyncEngine {
        if _engine == nil {
            self.initializeSyncEngine()
        }
        return _engine!
    }
    private var _engine: CKSyncEngine?
    
    private let dataURL: URL
    
    private struct State: Codable {
        var stateSerialization: CKSyncEngine.State.Serialization?
    }
    private var state: State
    
    public init(id: String, forkedResource: ForkedResource<R>, cloudKitContainer: CKContainer = .default()) throws {
        self.id = id
        self.forkedResource = forkedResource
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
        
        let stateData = (try? Data(contentsOf: dataURL)) ?? Data()
        self.state = (try? JSONDecoder().decode(State.self, from: stateData)) ?? State()
        
        try createFork()
    }
    
    /// Enqueues an upload when there is changed data in main
    private func sync() throws {
        if try forkedResource.hasUnmergedCommitsInMain(for: .cloudKit) {
            let content = try forkedResource.content(of: .main)
            if case .none = content {
                engine.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
            } else {
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            }
        }
    }
    
    internal func saveState() {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: dataURL)
        } catch {
            Logger.exchange.error("Failed to save state")
        }
    }
}

internal extension CloudKitExchange {
    
    func initializeSyncEngine() {
        let configuration: CKSyncEngine.Configuration =
            .init(
                database: cloudKitContainer.privateCloudDatabase,
                stateSerialization: state.stateSerialization,
                delegate: self
            )
        let syncEngine = CKSyncEngine(configuration)
        _engine = syncEngine
    }
    
    nonisolated func createFork() throws {
        if !forkedResource.has(.cloudKit) {
            try forkedResource.create(.cloudKit)
        }
    }
    
    nonisolated func removeFork() throws {
        if forkedResource.has(.cloudKit) {
            try forkedResource.mergeIntoMain(from: .cloudKit)
            try forkedResource.delete(.cloudKit)
        }
    }
    
}

@available(iOS 17.0, tvOS 17.0, watchOS 9.0, macOS 14.0, *)
extension CloudKitExchange: CKSyncEngineDelegate {
    
    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let event):
            state.stateSerialization = event.stateSerialization
            saveState()
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
        nil
    }
}
