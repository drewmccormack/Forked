import Foundation
import Observation

@Observable
class Store: Observable {
    static var defaultValue = Store()
    
    var forkers: [Forker]
    
    init(forkers: [Forker] = []) {
        self.forkers = forkers
    }
    
    func addForker(_ forker: Forker) {
        forkers.append(forker)
    }
    
    func updateForker(_ forker: Forker) {
        if let index = forkers.firstIndex(where: { $0.id == forker.id }) {
            forkers[index] = forker
        }
    }
    
    func deleteForker(at indexSet: IndexSet) {
        forkers.remove(atOffsets: indexSet)
    }
    
    func moveForker(from source: IndexSet, to destination: Int) {
        forkers.move(fromOffsets: source, toOffset: destination)
    }
} 