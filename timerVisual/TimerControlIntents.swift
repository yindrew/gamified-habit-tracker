//
//  TimerControlIntents.swift
//  timerVisual (Widget/Live Activity)
//
//  Duplicated type to allow Button(intent:) usage from the widget.
//  Execution occurs in the main app (openAppWhenRun).
//

import AppIntents
import ActivityKit
import SharedTimerModels

@available(iOS 16.1, *)
public struct ToggleHabitTimerIntent: AppIntent, LiveActivityIntent {
    public static var title = LocalizedStringResource("Toggle Habit Timer")
    public static var description = IntentDescription("Start or pause a habit timer from a Live Activity.")
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Should Run")
    public var shouldRun: Bool

    @Parameter(title: "Habit ID")
    public var habitId: String

    public init() {
        self.shouldRun = false
        self.habitId = ""
    }

    public init(habitId: String, shouldRun: Bool) {
        self.habitId = habitId
        self.shouldRun = shouldRun
    }

    public func perform() async throws -> some IntentResult {
        // Widget copy is a no-op. The app target handles real execution.
        return .result()
    }
}

