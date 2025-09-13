//
//  LiveActivityManager.swift
//  gamified-habit-tracker
//
//  Starts, updates, and stops the Live Activity for the running habit timer.
//  Uses shared TimerAttributes/TimerContentState models.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit
import UIKit
import SharedTimerModels

@available(iOS 16.1, *)
public final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    private var activities: [String: Activity<TimerAttributes>] = [:] // habitId -> activity
    private var pauseTimers: [String: Timer] = [:]

    func start(attributes: TimerAttributes, initialState: TimerContentState) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let habitId = attributes.habitId

        if let existing = activities[habitId] {
            Task {
                if #available(iOS 16.2, *) {
                    await existing.update(ActivityContent(state: initialState, staleDate: nil))
                } else {
                    await existing.update(using: initialState)
                }
            }
            return
        }

        do {
            let activity: Activity<TimerAttributes>
            if #available(iOS 16.2, *) {
                activity = try Activity<TimerAttributes>.request(
                    attributes: attributes,
                    content: ActivityContent(state: initialState, staleDate: nil),
                    pushType: nil
                )
            } else {
                activity = try Activity<TimerAttributes>.request(
                    attributes: attributes,
                    contentState: initialState,
                    pushType: nil
                )
            }
            activities[habitId] = activity
        } catch {
            #if DEBUG
            print("[LiveActivity] Not started: \(error)")
            #endif
        }
    }

    func update(habitId: String, state: TimerContentState) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        guard let activity = activities[habitId] else { return }
        Task {
            if #available(iOS 16.2, *) {
                await activity.update(ActivityContent(state: state, staleDate: nil))
            } else {
                await activity.update(using: state)
            }
        }
    }

    // Update to paused state and schedule auto-end after 5 minutes unless resumed
    func pause(habitId: String, state: TimerContentState) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        guard let activity = activities[habitId] else { return }
        // Cancel previous scheduled end
        pauseTimers[habitId]?.invalidate()
        pauseTimers.removeValue(forKey: habitId)
        Task {
            if #available(iOS 16.2, *) {
                await activity.update(ActivityContent(state: state, staleDate: nil))
            } else {
                await activity.update(using: state)
            }
        }
        let timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.stop(habitId: habitId, finalState: state)
        }
        pauseTimers[habitId] = timer
    }

    func stop(habitId: String, finalState: TimerContentState) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        guard let activity = activities[habitId] else { return }
        pauseTimers[habitId]?.invalidate()
        pauseTimers.removeValue(forKey: habitId)
        Task {
            if #available(iOS 16.2, *) {
                await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
            } else {
                await activity.end(using: finalState, dismissalPolicy: .immediate)
            }
            activities.removeValue(forKey: habitId)
        }
    }
}

#else

// Fallback no-op for platforms without ActivityKit.
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}
    func start(attributes: TimerAttributes, initialState: TimerContentState) {}
    func update(habitId: String, state: TimerContentState) {}
    func stop(habitId: String, finalState: TimerContentState) {}
}

#endif
