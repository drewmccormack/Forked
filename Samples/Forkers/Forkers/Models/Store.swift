import Foundation
import Observation

@Observable
class Store {
    var forkers: [Forker]
    
    init(forkers: [Forker] = []) {
        self.forkers = forkers
    }
    
    func addForker(_ forker: Forker) {
        forkers.append(forker)
    }
    
    func deleteForker(at indexSet: IndexSet) {
        forkers.remove(atOffsets: indexSet)
    }
    
    func moveForker(from source: IndexSet, to destination: Int) {
        forkers.move(fromOffsets: source, toOffset: destination)
    }
} 