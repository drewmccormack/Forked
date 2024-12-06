import Foundation
import ForkedModel
import ForkedMerge
import Forked

@ForkedModel
struct Forkers: Codable {
    @Merged var forkers: [Forker] = []
}

@ForkedModel
struct Forker: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var firstName: String = ""
    var lastName: String = ""
    var company: String = ""
    var birthday: Date?
    var email: String = ""
    var category: ForkerCategory?
    var color: ForkerColor?
    @Merged var notes: String = ""
}
