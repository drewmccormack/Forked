import Foundation
import Forked
import ForkedMerge
import ForkedModel
import SwiftUI

@ForkedModel
struct ForkerModel {
    @Merged var forkers: [Forker] = []
}

extension Fork {
    static let ui = Fork(name: "ui")
}

@Observable
class Store {
    @ObservationIgnored
    let forkedModel = QuickFork<ForkerModel>(initialValue: ForkerModel(), forks: [.ui])

    private var storedForkers: [Forker] {
        get {
            return try! forkedModel.resource(of: .ui)!.forkers
        }
        set {
            var model = try! forkedModel.resource(of: .ui)!
            model.forkers = newValue
            try! forkedModel.update(.ui, with: model)
            self.displayedForkers = newValue
        }
    }

    private(set) var displayedForkers: [Forker] = []

    init() {
        self.displayedForkers = storedForkers
    }

    func addForker(_ forker: Forker) {
        storedForkers.append(forker)
    }
    
    func updateForker(_ forker: Forker) {
        if let index = storedForkers.firstIndex(where: { $0.id == forker.id }) {
            storedForkers[index] = forker
        }
    }
    
    func deleteForker(at indexSet: IndexSet) {
        storedForkers.remove(atOffsets: indexSet)
    }
    
    func moveForker(from source: IndexSet, to destination: Int) {
        storedForkers.move(fromOffsets: source, toOffset: destination)
    }
}
