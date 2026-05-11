import SwiftUI

enum CyberAccent {
    case blue
    case cyan
    case green
    case amber
    case red
    case purple
    case neutral

    var color: Color {
        switch self {
        case .blue:
            return Color(red: 0.22, green: 0.48, blue: 1.0)
        case .cyan:
            return Color(red: 0.18, green: 0.82, blue: 0.96)
        case .green:
            return Color(red: 0.24, green: 0.78, blue: 0.50)
        case .amber:
            return Color(red: 0.95, green: 0.64, blue: 0.24)
        case .red:
            return Color(red: 0.90, green: 0.26, blue: 0.30)
        case .purple:
            return Color(red: 0.58, green: 0.42, blue: 0.96)
        case .neutral:
            return Color.white.opacity(0.72)
        }
    }

    var secondary: Color {
        switch self {
        case .blue:
            return .cyan
        case .cyan:
            return .blue
        case .green:
            return .mint
        case .amber:
            return .orange
        case .red:
            return .pink
        case .purple:
            return .blue
        case .neutral:
            return .white.opacity(0.32)
        }
    }
}
