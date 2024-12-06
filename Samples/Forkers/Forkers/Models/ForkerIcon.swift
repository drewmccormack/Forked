import Foundation

enum ForkerIcon: String, CaseIterable {
    case work
    case family
    case sports
    case education
    case gaming
    case music
    case art
    case travel
    case food
    case tech
    
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