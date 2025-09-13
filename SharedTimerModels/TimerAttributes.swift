//
//  TimerAttributes.swift
//  SharedTimerModels
//
//  Fixed attributes for the timer Live Activity.
//

import Foundation
import ActivityKit

@available(iOS 16.1, *)
public struct TimerAttributes: ActivityAttributes {
    // Bind this attributes type to the shared content state model
    public typealias ContentState = TimerContentState

    // Immutable properties identifying and styling the habit
    public var habitId: String          // Stable identifier (e.g., UUID string)
    public var name: String             // Habit name to display
    public var icon: String             // SF Symbol name
    public var colorHex: String         // Theme color (e.g., #007AFF)
    public var targetGoalSeconds: Int   // Target goal in seconds

    public init(habitId: String, name: String, icon: String, colorHex: String, targetGoalSeconds: Int) {
        self.habitId = habitId
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.targetGoalSeconds = targetGoalSeconds
    }
}

