import Foundation

struct Forker: Identifiable, Hashable {
    let id: UUID
    var firstName: String
    var lastName: String
    var company: String
    var notes: String
    var birthday: Date?
    var email: String
    var category: ForkerCategory?
    var color: ForkerColor?
    
    init(
        id: UUID = UUID(),
        firstName: String = "",
        lastName: String = "",
        company: String = "",
        notes: String = "",
        birthday: Date? = nil,
        email: String = "",
        category: ForkerCategory? = nil,
        color: ForkerColor? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.company = company
        self.notes = notes
        self.birthday = birthday
        self.email = email
        self.category = category
        self.color = color
    }
} 