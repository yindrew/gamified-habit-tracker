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
    @Published var pendingJournalEntry: HabitCompletion?

    // MARK: - Private runtime state
    private var timerManager: HabitTimerManager?
    private var viewContext: NSManagedObjectContext?
    private var lastJournaledCompletionID: NSManagedObjectID?

    init(habit: Habit) {
        self.habit = habit
        if let set = habit.completions as? Set<HabitCompletion> {
            let latestNonJournal = set
                .filter { !$0.isJournalOnly }
                .sorted { ($0.completedDate ?? .distantPast) > ($1.completedDate ?? .distantPast) }
                .first
            self.lastJournaledCompletionID = latestNonJournal?.objectID
        }
    }

    // MARK: - Configuration
    func setContext(_ context: NSManagedObjectContext) {
        self.viewContext = context
        // Reuse any existing manager for this habit so intent actions and UI stay in sync
        let manager: HabitTimerManager
        if let id = habit.id?.uuidString, let existing = HabitTimerManager.existingManager(for: id) {
            manager = existing
        } else {
            manager = HabitTimerManager(habit: habit, context: context)
        }
        manager.onTick = { [weak self] elapsed in
            self?.timerElapsedTime = elapsed
        }
        manager.onRunningChanged = { [weak self] running in
            self?.isTimerRunning = running
        }
        manager.onAutoStop = { [weak self] in
            guard let self else { return }
            self.didAutoStopAtGoal = true
            _ = self.captureCompletionIfNeeded(newCompletion: self.latestCompletion())
        }
        self.timerManager = manager
        self.lastJournaledCompletionID = self.latestCompletion()?.objectID
        self.pendingJournalEntry = nil
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
        )) as? Set<HabitCompletion>

        return todayCompletions?.filter { !$0.isJournalOnly }.count ?? 0
    }

    var progressPercentage: Double {
        if habit.isRoutineHabit {
            return habit.updatedRoutineProgressPercentage
        } else if habit.isTimerHabit {
            let totalMinutes = habit.timerMinutesToday + (timerElapsedTime / 60.0)
            let goal = max(habit.goalValue, 0.000001)
            return min(totalMinutes / goal, 1.0)
        } else if habit.isEtherealHabit {
            return habit.goalMetToday ? 1.0 : 0.0
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
        } else if habit.isEtherealHabit {
            return habit.goalMetToday
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

    var hasAnyCompletion: Bool {
        guard let set = habit.completions as? Set<HabitCompletion> else { return false }
        return set.contains { !$0.isJournalOnly }
    }

    var progressText: String {
        if habit.isTimerHabit {
            // Always show stopwatch style that counts up; persists across pauses.
            return elapsedDisplay
        } else if habit.isEtherealHabit {
            return habit.currentProgressString
        } else if habit.isScheduledToday {
            return habit.currentProgressString
        } else {
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = habit.allowsFractionalMetrics ? 1 : 0
            let amount = habit.frequencyMetricProgressToday
            let amountString = formatter.string(from: NSNumber(value: amount)) ?? "0"
            let unit = habit.metricUnit ?? "times"
            return "\(amountString) \(unit)"
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
        timerManager?.start(allowOverrun: allowOverrun, initialElapsed: totalElapsedSecondsToday)
    }

    @discardableResult
    func pauseTimer(saveProgress: Bool) -> HabitCompletion? {
        timerManager?.pause(saveProgress: saveProgress)
        let triggered = captureCompletionIfNeeded(newCompletion: latestCompletion())
        return triggered ? pendingJournalEntry : nil
    }

    // Timer persistence handled by HabitTimerManager

    @discardableResult
    func completeHabit() -> HabitCompletion? {
        guard let context = viewContext else { return nil }

        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()

        let completion = HabitCompletion(context: context)
        completion.id = UUID()
        completion.completedDate = Date()
        completion.habit = habit
        if !habit.isTimerHabit && !habit.isRoutineHabit && !habit.isEtherealHabit {
            completion.metricAmount = habit.metricValue
        }

        habit.totalCompletions += 1
        habit.lastCompletedDate = Date()
        updateStreak()

        if habit.isEtherealHabit {
            habit.isActive = false
        }
        do {
            try context.save()
            HabitWidgetExporter.shared.scheduleSync(using: context)
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        _ = captureCompletionIfNeeded(newCompletion: completion)
        return completion
    }


    func prepareAdditionalReflection(createNewJournalEntry: Bool = false) -> HabitCompletion? {
        if createNewJournalEntry {
            guard let context = viewContext else { return nil }
            let entry = HabitCompletion(context: context)
            entry.id = UUID()
            entry.completedDate = Date()
            entry.habit = habit
            entry.isJournalOnly = true
            pendingJournalEntry = entry
            return entry
        }

        guard let entry = latestCompletion() else {
            pendingJournalEntry = nil
            return nil
        }
        pendingJournalEntry = entry
        return entry
    }

    func completeCopingPlan() {
        guard let context = viewContext else { return }

        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        habit.completeCopingPlan()

        do {
            try context.save()
            HabitWidgetExporter.shared.scheduleSync(using: context)
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    func toggleStep(at index: Int) {
        guard habit.isRoutineHabit, let context = viewContext else { return }

        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        let completion = HabitCompletion(context: context)
        completion.id = UUID()
        completion.completedDate = Date()
        completion.habit = habit
        completion.completedSteps = "\(index)"

        do {
            try context.save()
            HabitWidgetExporter.shared.scheduleSync(using: context)
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }

        let isNowFullyCompleted = habit.updatedGoalMetToday
        if !habit.isEtherealHabit && isNowFullyCompleted {
            habit.totalCompletions += 1
            habit.lastCompletedDate = Date()
            updateStreak()
            do {
                try context.save()
                HabitWidgetExporter.shared.scheduleSync(using: context)
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
        _ = captureCompletionIfNeeded(newCompletion: completion)
    }

    // MARK: - Helpers

    @discardableResult
    private func captureCompletionIfNeeded(newCompletion: HabitCompletion?) -> Bool {
        guard !habit.isEtherealHabit else { return false }
        guard shouldPromptForJournal else { return false }
        let entry = newCompletion ?? latestCompletion()
        guard let entry, !entry.isJournalOnly else { return false }
        if let lastID = lastJournaledCompletionID, lastID == entry.objectID {
            return false
        }
        pendingJournalEntry = entry
        lastJournaledCompletionID = entry.objectID
        return true
    }

    private func latestCompletion() -> HabitCompletion? {
        guard let set = habit.completions as? Set<HabitCompletion>, !set.isEmpty else { return nil }
        return set
            .filter { !$0.isJournalOnly }
            .sorted { (lhs, rhs) in
            (lhs.completedDate ?? .distantPast) > (rhs.completedDate ?? .distantPast)
        }.first
    }

    private var shouldPromptForJournal: Bool {
        if habit.isTimerHabit { return habit.timerGoalMetToday }
        if habit.isRoutineHabit { return habit.updatedGoalMetToday }
        return habit.goalMetToday
    }

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
