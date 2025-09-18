import SwiftUI

enum MoodPalette {
    static func color(for score: Int) -> Color {
        switch score {
        case 1:
            return .red
        case 2:
            return .orange
        case 3:
            return .yellow
        case 4:
            return Color(red: 0.6, green: 0.85, blue: 0.5)
        default:
            return .green
        }
    }

    static func label(for score: Int) -> String {
        switch score {
        case 1: return "Very Negative"
        case 2: return "Negative"
        case 3: return "Neutral"
        case 4: return "Positive"
        default: return "Very Positive"
        }
    }
}
