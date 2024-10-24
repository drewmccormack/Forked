import Forked
import ForkedCloudKit
import Foundation

extension Fork {
    static let ui = Fork(name: "ui")
}

@Observable
class Store {
    private typealias RepoType = AtomicRepository<String>
    private let repo: RepoType
    private let forkedText: ForkedResource<RepoType>
    private let cloudKitExchange: CloudKitExchange<RepoType>
    private static let repoFileURL: URL =
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ForkedRepo.json")
    
    public var displayedText: String {
        didSet {
            guard displayedText != textInRepo else { return }
            try! forkedText.update(.ui, with: displayedText)
            try! forkedText.mergeIntoMain(from: .ui)
        }
    }
    
    /// Current value in .ui fork of repo
    private var textInRepo: String {
        try! forkedText.resource(of: .ui)!
    }

    init() throws {
        // Read repo from disk if it exists, otherwise create anew
        if FileManager.default.fileExists(atPath: Self.repoFileURL.path) {
            let data = try! Data(contentsOf: Self.repoFileURL)
            repo = try! JSONDecoder().decode(RepoType.self, from: data)
        } else {
            repo = .init()
        }
        
        // Setup ForkedResource
        forkedText = try .init(repository: repo)
        if !forkedText.has(.ui) {
            try forkedText.create(.ui)
            try forkedText.update(.ui, with: "Fork yeah!") // First text in UI
        }
     
        // Setup CloudKitExchange
        cloudKitExchange = try .init(id: "ForkingSimpleICloudData", forkedResource: forkedText)
        
        // Set displayed text to what is in the repo
        displayedText = try! forkedText.resource(of: .ui)!
        
        // Monitor stream of updates to resource (eg remote sync changes)
        Task {
            for await change in forkedText.changeStream where change.fork == .main && change.mergingFork != .ui {
                try! forkedText.mergeFromMain(into: .ui)
                displayedText = textInRepo
            }
        }
    }
    
    func save() throws {
        try! JSONEncoder().encode(repo).write(to: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("repo.json"))
    }
}
