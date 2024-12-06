import SwiftUI

enum ForkerColor: String, CaseIterable, Codable {
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case blue
    case indigo
    case purple
    case pink
    
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .mint: return .mint
        case .teal: return .teal
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        }
    }
} 