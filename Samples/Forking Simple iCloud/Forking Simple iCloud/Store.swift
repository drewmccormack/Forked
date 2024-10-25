import Forked
import ForkedCloudKit
import Foundation

extension Fork {
    static let ui = Fork(name: "ui")
}

struct Model: Codable {
    var text: String
}

@Observable
class Store {
    private typealias RepoType = AtomicRepository<Model>
    private let repo: RepoType
    private let forkedText: ForkedResource<RepoType>
    private let cloudKitExchange: CloudKitExchange<RepoType>
    
    private static let repoDirURL: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    private static let repoFileURL: URL = repoDirURL.appendingPathComponent("ForkedRepo.json")
    private let fileManager = FileManager()
    
    /// Current value in .ui fork of repo
    private var model: Model {
        try! forkedText.resource(of: .ui)!
    }
    
    public var displayedText: String {
        didSet {
            guard displayedText != model.text else { return }
            try! forkedText.update(.ui, with: Model(text: displayedText))
            try! forkedText.mergeIntoMain(from: .ui)
        }
    }

    init() throws {
        // Read repo from disk if it exists, otherwise create anew
        if fileManager.fileExists(atPath: Self.repoFileURL.path) {
            let data = try Data(contentsOf: Self.repoFileURL)
            repo = try JSONDecoder().decode(RepoType.self, from: data)
        } else {
            try? fileManager.createDirectory(at: Self.repoDirURL, withIntermediateDirectories: true)
            repo = .init()
        }
        
        // Setup ForkedResource
        forkedText = try .init(repository: repo)
        if !forkedText.has(.ui) {
            try forkedText.create(.ui)
            try forkedText.update(.ui, with: Model(text: "Fork yeah!")) // First text in UI
        }
     
        // Setup CloudKitExchange
        cloudKitExchange = try .init(id: "ForkingSimpleICloudData", forkedResource: forkedText)
        
        // Set displayed text to what is in the repo
        displayedText = try forkedText.resource(of: .ui)!.text
        
        // Monitor stream of updates to resource (eg remote sync changes)
        Task {
            try! forkedText.mergeFromMain(into: .ui)
            for await change in forkedText.changeStream where change.fork == .main && change.mergingFork != .ui {
                try! forkedText.mergeFromMain(into: .ui)
                displayedText = model.text
            }
        }
    }
    
    func save() throws {
        try! JSONEncoder().encode(repo).write(to: Self.repoFileURL)
    }
}
