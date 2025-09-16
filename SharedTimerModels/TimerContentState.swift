//
//  TimerContentState.swift
//  SharedTimerModels
//
//  Represents the dynamic state for the timer Live Activity.
//

import Foundation

@available(iOS 16.1, *)
public struct TimerContentState: Codable, Hashable {
    // Baseline elapsed seconds accumulated prior to current session
    public var baseElapsedSeconds: Int
    // Start date of the current running session (nil when paused)
    public var sessionStartDate: Date?

    // Flags to render running/paused/finished UI states
    public var isRunning: Bool
    public var isFinished: Bool

    public init(baseElapsedSeconds: Int, sessionStartDate: Date?, isRunning: Bool, isFinished: Bool) {
        self.baseElapsedSeconds = baseElapsedSeconds
        self.sessionStartDate = sessionStartDate
        self.isRunning = isRunning
        self.isFinished = isFinished
    }
}
