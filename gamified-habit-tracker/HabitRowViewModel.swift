//
//  HabitRowViewModel.swift
//  gamified-habit-tracker
//
//  Provides state, derived UI, and intents for HabitRowView
//

import SwiftUI
import CoreData
import UIKit


final class HabitRowViewModel: ObservableObject {
    // MARK: - Input / Model
    @Published var habit: Habit

    // MARK: - UI State
    @Published var timerElapsedTime: TimeInterval = 0 // source of truth for elapsed
    @Published var isTimerRunning: Bool = false
    @Published var isRoutineExpanded: Bool = false
    @Published var didAutoStopAtGoal: Bool = false

    // MARK: - Private runtime state
    private var runningTimer: Timer?
    private var timerStartTime: Date?
    private var sessionAllowsOverrun: Bool = false
    private var viewContext: NSManagedObjectContext?

    init(habit: Habit) {
        self.habit = habit
    }

    // MARK: - Configuration
    func setContext(_ context: NSManagedObjectContext) {
        self.viewContext = context
    }

    // MARK: - Derived Values
    var isCompletedToday: Bool {
        guard let lastCompleted = habit.lastCompletedDate else { return false }
        return Calendar.current.isDateInToday(lastCompleted)
    }

    var completionsToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let todayCompletions = habit.completions?.filtered(using: NSPredicate(
            format: "completedDate >= %@ AND completedDate < %@",
            today as NSDate,
            tomorrow as NSDate
        ))
        return todayCompletions?.count ?? 0
    }

    var progressPercentage: Double {
        if habit.isRoutineHabit {
            return habit.updatedRoutineProgressPercentage
        } else if habit.isTimerHabit {
            let totalMinutes = habit.timerMinutesToday + (timerElapsedTime / 60.0)
            let goal = max(habit.goalValue, 0.000001)
            return min(totalMinutes / goal, 1.0)
        } else if habit.isScheduledToday {
            return habit.progressPercentage
        } else {
            return completionsToday > 0 ? 1.0 : 0.0
        }
    }

    var isCompletedForDisplay: Bool {
        if habit.isRoutineHabit {
            return habit.updatedGoalMetToday
        } else if habit.isTimerHabit {
            return habit.timerGoalMetToday
        } else if habit.isScheduledToday {
            return habit.goalMetToday
        } else {
            return completionsToday > 0
        }
    }

    var timerRemainingDisplay: String {
        // goalValue is in minutes (Double). Include live elapsed time.
        let completedSeconds = (habit.timerMinutesToday * 60.0) + timerElapsedTime
        let goalSeconds = max(habit.goalValue * 60.0, 0)
        let remaining = max(0, goalSeconds - completedSeconds)
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        if remaining >= 3600 {
            return String(format: "%dh %dm left", hours, minutes)
        } else if remaining >= 60 {
            return String(format: "%dm left", minutes)
        } else {
            return String(format: "%ds left", seconds)
        }
    }

    var buttonIcon: String {
        if habit.canUseCopingPlanToday {
            return "heart.fill"
        } else if habit.isTimerHabit {
            return timerButtonIcon
        } else if isCompletedForDisplay {
            return "checkmark"
        } else {
            return "plus"
        }
    }

    var buttonBackgroundColor: Color {
        if habit.canUseCopingPlanToday {
            return Color.pink.opacity(0.1)
        } else if isCompletedForDisplay {
            return Color(hex: habit.colorHex ?? "#007AFF")
        } else {
            return Color(hex: habit.colorHex ?? "#007AFF").opacity(0.1)
        }
    }

    var buttonIconColor: Color {
        if habit.canUseCopingPlanToday {
            return .pink
        } else if isCompletedForDisplay {
            return .white
        } else {
            return Color(hex: habit.colorHex ?? "#007AFF")
        }
    }
    
    // Extra minutes beyond today's goal (rounded down)
    var overrunText: String? {
        guard habit.isTimerHabit else { return nil }
        let completedSeconds = totalElapsedSecondsToday
        let goalSeconds = max(habit.goalValue * 60.0, 0)
        let extra = max(0, completedSeconds - goalSeconds)
        let minutes = Int(extra / 60.0)
        return minutes > 0 ? "+\(minutes)m" : nil
    }
    
    // Total elapsed today = persisted + current live session
    var totalElapsedSecondsToday: TimeInterval {
        (habit.timerMinutesToday * 60.0) + timerElapsedTime
    }

    private var elapsedDisplay: String {
        let total = Int(totalElapsedSecondsToday)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var progressText: String {
        if habit.isTimerHabit {
            // Always show stopwatch style that counts up; persists across pauses.
            return elapsedDisplay
        } else if habit.isScheduledToday {
            return habit.currentProgressString
        } else {
            let unit = habit.metricUnit ?? "times"
            return "\(completionsToday) \(unit)"
        }
    }

    var timerButtonIcon: String {
        if isTimerRunning { return "pause.fill" }
        return habit.timerGoalMetToday ? "checkmark" : "play.fill"
    }

    // MARK: - Intents
    func startTimer(allowOverrun: Bool = false) {
        // Need context to persist when goal reached
        guard viewContext != nil else { return }

        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        didAutoStopAtGoal = false
        isTimerRunning = true
        timerStartTime = Date()
        // Start fresh live session; UI uses totalElapsedSecondsToday
        timerElapsedTime = 0
        sessionAllowsOverrun = allowOverrun

        runningTimer?.invalidate()
        runningTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let start = self.timerStartTime {
                self.timerElapsedTime = Date().timeIntervalSince(start)

                // Check if goal is completed
                let totalMinutesToday = self.habit.timerMinutesToday + (self.timerElapsedTime / 60.0)
                if totalMinutesToday >= self.habit.goalValue && !self.sessionAllowsOverrun {
                    self.pauseTimer(saveProgress: true)
                    self.didAutoStopAtGoal = true
                }
            }
        }
    }

    func pauseTimer(saveProgress: Bool) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        runningTimer?.invalidate()
        runningTimer = nil
        isTimerRunning = false

        if saveProgress {
            let delta: TimeInterval
            if let start = timerStartTime { delta = Date().timeIntervalSince(start) } else { delta = timerElapsedTime }
            saveTimerProgress(deltaSeconds: max(0, delta))
        }
        timerStartTime = nil
        // Reset live session; UI remains steady via persisted totals
        timerElapsedTime = 0
    }

    func saveTimerProgress(deltaSeconds: TimeInterval) {
        guard deltaSeconds > 0 else { return }
        guard let context = viewContext else { return }

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
            // Persisted totals now reflect the segment; live session resets in pause
        } catch {
            print("Error saving timer completion: \(error)")
        }
    }

    func completeHabit() {
        guard let context = viewContext else { return }

        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()

        let completion = HabitCompletion(context: context)
        completion.id = UUID()
        completion.completedDate = Date()
        completion.habit = habit

        habit.totalCompletions += 1
        habit.lastCompletedDate = Date()
        updateStreak()

        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    func completeCopingPlan() {
        guard let context = viewContext else { return }

        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        habit.completeCopingPlan()

        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    func toggleStep(at index: Int) {
        guard habit.isRoutineHabit, let context = viewContext else { return }

        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        let wasFullyCompleted = habit.updatedGoalMetToday

        let completion = HabitCompletion(context: context)
        completion.id = UUID()
        completion.completedDate = Date()
        completion.habit = habit
        completion.completedSteps = "\(index)"

        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }

        let isNowFullyCompleted = habit.updatedGoalMetToday
        if !wasFullyCompleted && isNowFullyCompleted {
            habit.totalCompletions += 1
            habit.lastCompletedDate = Date()
            updateStreak()
            do { try context.save() } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    // MARK: - Helpers
    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let lastCompleted = habit.lastCompletedDate else {
            habit.currentStreak = 1
            habit.longestStreak = max(habit.longestStreak, 1)
            return
        }

        let lastCompletedDay = calendar.startOfDay(for: lastCompleted)
        let daysBetween = calendar.dateComponents([.day], from: lastCompletedDay, to: today).day ?? 0

        if daysBetween == 0 {
            return
        } else if daysBetween == 1 {
            habit.currentStreak += 1
        } else {
            habit.currentStreak = 1
        }

        habit.longestStreak = max(habit.longestStreak, habit.currentStreak)
    }

}
