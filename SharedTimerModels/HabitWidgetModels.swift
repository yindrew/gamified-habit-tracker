//
//  HabitWidgetModels.swift
//  SharedTimerModels
//
//  Lightweight models shared between the main app and widget extensions
//  to render habit summary widgets.
//

import Foundation
import SwiftUI

public enum HabitWidgetMode: String, Codable, Hashable, CaseIterable {
    case count
    case timer

    public var requiresIncrementIntent: Bool { self == .count }
    public var requiresTimerIntent: Bool { self == .timer }
}

public struct HabitWidgetSnapshot: Codable, Hashable, Identifiable {
    public let id: String
    public var name: String
    public var icon: String
    public var colorHex: String
    public var mode: HabitWidgetMode

    /// Current progress value expressed in the habit's native units (minutes, count, etc.)
    public var value: Double
    /// Daily goal value expressed in the same units as `value`. Must be > 0 to compute progress safely.
    public var goal: Double

    /// Optional display helpers
    public var unitLabel: String?
    public var isTimerRunning: Bool?
    public var lastUpdated: Date

    public init(
        id: String,
        name: String,
        icon: String,
        colorHex: String,
        mode: HabitWidgetMode,
        value: Double,
        goal: Double,
        unitLabel: String? = nil,
        isTimerRunning: Bool? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.mode = mode
        self.value = value
        self.goal = goal
        self.unitLabel = unitLabel
        self.isTimerRunning = isTimerRunning
        self.lastUpdated = lastUpdated
    }

    public var progress: Double {
        guard goal > 0 else { return 0 }
        return min(max(value / goal, 0), 1)
    }

    public var formattedProgress: String {
        switch mode {
        case .timer:
            let totalSeconds = Int(value * 60)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else if minutes > 0 {
                return String(format: "%d:%02d", minutes, seconds)
            } else {
                return String(format: "%ds", seconds)
            }
        case .count:
            let formatter = NumberFormatter()
            formatter.maximumFractionDigits = 1
            formatter.minimumFractionDigits = 0
            let valueString = formatter.string(from: NSNumber(value: value)) ?? "0"
            let goalString = formatter.string(from: NSNumber(value: goal)) ?? "0"
            if let unitLabel, !unitLabel.isEmpty {
                return "\(valueString)/\(goalString) \(unitLabel)"
            } else {
                return "\(valueString)/\(goalString)"
            }
        }
    }

    public static var placeholder: HabitWidgetSnapshot {
        HabitWidgetSnapshot(
            id: "placeholder",
            name: "Daily Focus",
            icon: "target",
            colorHex: "#007AFF",
            mode: .count,
            value: 2,
            goal: 3,
            unitLabel: "times"
        )
    }

    public static let sampleTimer = HabitWidgetSnapshot(
        id: "timer",
        name: "Meditate",
        icon: "timer",
        colorHex: "#34C759",
        mode: .timer,
        value: 22.5,
        goal: 30,
        unitLabel: "minutes",
        isTimerRunning: true
    )
}

public enum HabitWidgetStoreConstants {
    public static let suiteName = "group.yin.gamified-habit-tracker"
    public static let snapshotsKey = "habit_widget_snapshots"
}
