import Foundation
import ForkedModel
import ForkedMerge
import Forked

/// How much a Forker owes you.
struct Balance: Mergeable, Codable, Hashable {
    var dollarAmount: Float = 0.0
    func merged(withSubordinate other: Self, commonAncestor: Self) throws -> Self {
        Self(dollarAmount: dollarAmount + other.dollarAmount - commonAncestor.dollarAmount)
    }
}

@ForkedModel(version: 0)
struct Forkers: Codable {
    @Merged(using: .arrayOfIdentifiableMerge) var forkers: [Forker] = []
}

@ForkedModel(version: 0)
struct Forker: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var firstName: String = ""
    var lastName: String = ""
    var company: String = ""
    var birthday: Date?
    var email: String = ""
    var category: ForkerCategory?
    var color: ForkerColor?
    @Merged var balance: Balance = .init()
    @Merged var notes: String = ""
    @Merged var tags: Set<String> = []
}

extension Forkers {
    
    func salvaging(from other: Forkers) throws -> Forkers {
        // When two devices have unrelated histories, they can't be
        // 3-way merged. Instead, we will start with the dominant
        // forker values (eg from the cloud), and copy in any forkers unique
        // to the subordinate data (eg local)
        var new = self
        let ids = Set(self.forkers.map(\.id))
        new.forkers += other.forkers.filter { !ids.contains($0.id) }
        return new
    }
    
}
