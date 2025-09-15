//
//  HabitTimerManager.swift
//  gamified-habit-tracker
//
//  Encapsulates timer lifecycle, persistence, haptics, and Live Activity updates
//  for timer-type habits.
//

import Foundation
import CoreData
import UIKit
import SharedTimerModels

final class HabitTimerManager {
    // Shared registry so multiple callers reuse the same manager per habit
    private class WeakBox<T: AnyObject> { weak var value: T?; init(_ value: T) { self.value = value } }
    private static var registry: [String: WeakBox<HabitTimerManager>] = [:]
    static func existingManager(for habitId: String) -> HabitTimerManager? {
        // Clean up any deallocated entries lazily
        if let box = registry[habitId], box.value == nil { registry.removeValue(forKey: habitId) }
        return registry[habitId]?.value
    }
    private static func register(_ manager: HabitTimerManager, habitId: String) {
        registry[habitId] = WeakBox(manager)
    }
    // Inputs
    private let habit: Habit
    private let context: NSManagedObjectContext

    // Runtime state
    private var runningTimer: Timer?
    private var timerStartTime: Date?
    private var sessionAllowsOverrun: Bool = false
    private var baseElapsedAtStart: TimeInterval = 0

    // Outputs
    private(set) var isRunning: Bool = false { didSet { onRunningChanged?(isRunning) } }
    private(set) var elapsedTime: TimeInterval = 0 { didSet { onTick?(elapsedTime) } }
    private(set) var didAutoStopAtGoal: Bool = false { didSet { if didAutoStopAtGoal { onAutoStop?() } } }

    // Callbacks for UI/view model integration
    var onTick: ((TimeInterval) -> Void)?
    var onRunningChanged: ((Bool) -> Void)?
    var onAutoStop: (() -> Void)?



    init(habit: Habit, context: NSManagedObjectContext) {
        self.habit = habit
        self.context = context
        // no-op: Live Activity is started when the timer starts
        if let id = habit.id?.uuidString {
            HabitTimerManager.register(self, habitId: id)
        }
    }

    func start(allowOverrun: Bool = false, initialElapsed: TimeInterval) {
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        didAutoStopAtGoal = false
        isRunning = true
        timerStartTime = Date()
        elapsedTime = 0
        sessionAllowsOverrun = allowOverrun
        baseElapsedAtStart = initialElapsed


        // Start/refresh Live Activity for this habit
        if let attrs = buildAttributes() {
            let state = TimerContentState(
                elapsedSeconds: Int(initialElapsed),
                isRunning: true,
                isFinished: false
            )
            LiveActivityManager.shared.start(attributes: attrs, initialState: state)
        }

        runningTimer?.invalidate()
        runningTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.timerStartTime else { return }
            self.elapsedTime = Date().timeIntervalSince(start)

            // Auto-stop once goal reached when overruns not allowed
            let totalMinutesToday = self.habit.timerMinutesToday + (self.elapsedTime / 60.0)
            if totalMinutesToday >= self.habit.goalValue && !self.sessionAllowsOverrun {
                SoundManager.playTimerComplete()
                // Send finished state and end activity
                if let habitId = self.habit.id?.uuidString {
                    let finishedState = TimerContentState(
                        elapsedSeconds: Int(self.baseElapsedAtStart + self.elapsedTime),
                        isRunning: false,
                        isFinished: true
                    )
                    LiveActivityManager.shared.stop(habitId: habitId, finalState: finishedState)
                }
                self.pause(saveProgress: true)
                self.didAutoStopAtGoal = true
                return
            }

            // Live Activity periodic update
            if let habitId = self.habit.id?.uuidString {
                let state = TimerContentState(
                    elapsedSeconds: Int(self.baseElapsedAtStart + self.elapsedTime),
                    isRunning: true,
                    isFinished: false
                )
                LiveActivityManager.shared.update(habitId: habitId, state: state)
            }
        }
    }

    func pause(saveProgress: Bool) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        runningTimer?.invalidate()
        runningTimer = nil
        isRunning = false

        if saveProgress {
            let delta: TimeInterval
            if let start = timerStartTime {
                delta = Date().timeIntervalSince(start)
            } else {
                delta = elapsedTime
            }
            persistTimerProgress(deltaSeconds: max(0, delta))
        }
        timerStartTime = nil
        // Send paused state and keep the activity visible (auto-ends later)
        if let habitId = habit.id?.uuidString {
            let state = TimerContentState(
                elapsedSeconds: Int(baseElapsedAtStart + elapsedTime),
                isRunning: false,
                isFinished: false
            )
            LiveActivityManager.shared.pause(habitId: habitId, state: state)
        }

        elapsedTime = 0
    }

    private func persistTimerProgress(deltaSeconds: TimeInterval) {
        guard deltaSeconds > 0 else { return }

        let completion = HabitCompletion(context: context)
        completion.id = UUID()
        completion.completedDate = Date()
        completion.habit = habit
        completion.timerDuration = deltaSeconds / 60.0 // minutes saved for this segment

        // Update habit statistics if goal is reached for the first time today
        let totalMinutesToday = habit.timerMinutesToday + (deltaSeconds / 60.0)
        if totalMinutesToday >= habit.goalValue && !habit.timerGoalMetToday {
            habit.totalCompletions += 1
            habit.lastCompletedDate = Date()
        }

        do {
            try context.save()
        } catch {
            print("Error saving timer completion: \(error)")
        }
    }
}

// MARK: - Helpers
private extension HabitTimerManager {
    func buildAttributes() -> TimerAttributes? {
        guard let uuid = habit.id?.uuidString else { return nil }
        let goalSeconds = Int(max(0, habit.goalValue) * 60)
        return TimerAttributes(
            habitId: uuid,
            name: habit.name ?? "Habit",
            icon: habit.icon ?? "timer",
            colorHex: habit.colorHex ?? "#007AFF",
            targetGoalSeconds: goalSeconds
        )
    }
}

// MARK: - High-level control API
extension HabitTimerManager {
    /// Start or resume the timer using the habit's current progress and goal.
    /// Decides whether overruns are allowed and seeds the initial elapsed baseline.
    func run() {
        let minutesSoFar = habit.timerMinutesToday
        let allow = habit.timerGoalMetToday || (minutesSoFar >= habit.goalValue)
        start(allowOverrun: allow, initialElapsed: minutesSoFar * 60.0)
    }

    /// Pause the timer and persist progress.
    func pauseAndSave() {
        pause(saveProgress: true)
    }

    /// Toggle based on desired running state.
    func toggle(shouldRun: Bool) {
        if shouldRun { run() } else { pauseAndSave() }
    }
}
