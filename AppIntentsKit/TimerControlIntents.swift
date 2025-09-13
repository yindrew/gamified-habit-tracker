//
//  TimerControlIntents.swift
//  gamified-habit-tracker
//
//  AppIntents to start/stop (pause) a habit timer and manage Live Activities.
//

import AppIntents

public protocol HabitTimerControlling: Sendable {
    func toggleTimer(habitId: String, shouldRun: Bool) async
}

public enum HabitTimerBridge {
    public static var controller: HabitTimerControlling?
}

@available(iOS 16.1, *)
public struct ToggleHabitTimerIntent: SetValueIntent {
    public static var title: LocalizedStringResource = "Toggle Habit Timer"

    @Parameter(title: "Habit ID") public var habitId: String
    @Parameter(title: "Timer Running") public var value: Bool

    public init() {}
    public init(habitId: String) { self.habitId = habitId }

    public func perform() async throws -> some IntentResult {
        await HabitTimerBridge.controller?.toggleTimer(habitId: habitId, shouldRun: value)
        return .result()
    }
}
