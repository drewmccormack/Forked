import Foundation

enum ForkerIcon: String, CaseIterable {
    case work = "Work"
    case family = "Family"
    case sports = "Sports"
    case education = "Education"
    case gaming = "Gaming"
    case music = "Music"
    case art = "Art"
    case travel = "Travel"
    case food = "Food"
    case tech = "Technology"
    
    var systemImage: String {
        switch self {
        case .work:
            return "briefcase.fill"
        case .family:
            return "house.fill"
        case .sports:
            return "figure.run"
        case .education:
            return "book.fill"
        case .gaming:
            return "gamecontroller.fill"
        case .music:
            return "music.note"
        case .art:
            return "paintbrush.fill"
        case .travel:
            return "airplane"
        case .food:
            return "fork.knife"
        case .tech:
            return "laptopcomputer"
        }
    }
} 