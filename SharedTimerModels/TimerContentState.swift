//
//  TimerContentState.swift
//  SharedTimerModels
//
//  Represents the dynamic state for the timer Live Activity.
//

import Foundation

@available(iOS 16.1, *)
public struct TimerContentState: Codable, Hashable {
    // Elapsed time in seconds (monotonic within the current activity session)
    public var elapsedSeconds: Int

    // Flags to render running/paused/finished UI states
    public var isRunning: Bool
    public var isFinished: Bool

    public init(elapsedSeconds: Int, isRunning: Bool, isFinished: Bool) {
        self.elapsedSeconds = elapsedSeconds
        self.isRunning = isRunning
        self.isFinished = isFinished
    }
}
