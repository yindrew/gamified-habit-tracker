// //
// //  HabitRowViewModel.swift
// //  gamified-habit-tracker
// //
// //  Provides state, derived UI, and intents for HabitRowView
// //

// import Foundation
// import SwiftUI
// import CoreData
// import Combine

// final class HabitRowViewModel: ObservableObject {
//     // MARK: - Inputs
//     let habit: Habit
//     private let ctx: NSManagedObjectContext

//     // MARK: - Timer state
//     @Published private(set) var isTimerRunning = false
//     @Published private(set) var elapsedSeconds: TimeInterval = 0
//     private var timer: Timer?
//     private var startDate: Date?

//     // MARK: - UI / Derived state
//     @Published private(set) var progressPercent: Double = 0
//     @Published private(set) var progressText: String = ""
//     @Published private(set) var isCompletedForDisplay: Bool = false
//     @Published private(set) var mainButtonIcon: String = "plus"
//     @Published private(set) var mainFillColor: Color = .blue
//     @Published private(set) var mainIconColor: Color = .white

//     // Focus / expand sheet for timers
//     @Published var showFocusMode = false

//     private var cancellables = Set<AnyCancellable>()

//     // MARK: - Init
//     init(habit: Habit, context: NSManagedObjectContext) {
//         self.habit = habit
//         self.ctx = context

//         // Keep derived UI in sync on any Core Data change
//         NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
//             .receive(on: RunLoop.main)
//             .sink { [weak self] _ in self?.recompute() }
//             .store(in: &cancellables)

//         recompute()
//     }

//     deinit { invalidateTimer() }

//     // MARK: - Public intents called by the View

//     /// Called after the press-and-hold ring completes.
//     func onHoldCompleted() {
//         if habit.canUseCopingPlanToday {
//             completeCopingPlan()
//         } else if habit.isTimerHabit {
//             if !habit.timerGoalMetToday { toggleTimer() }
//         } else if habit.isRoutineHabit {
//             completeNextRoutineStep()
//         } else {
//             completeOnce()
//         }
//         recompute()
//     }

//     func toggleTimer() {
//         isTimerRunning ? pauseTimer(save: true) : startTimer()
//     }

//     func startTimer() {
//         guard !isTimerRunning, !habit.timerGoalMetToday else { return }
//         UIImpactFeedbackGenerator(style: .medium).impactOccurred()

//         isTimerRunning = true
//         startDate = Date()
//         elapsedSeconds = 0

//         timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
//             guard let self, let start = self.startDate else { return }
//             self.elapsedSeconds = Date().timeIntervalSince(start)

//             // Stop automatically when today’s goal reached
//             let totalMinutes = habit.timerMinutesToday + elapsedSeconds / 60.0
//             if totalMinutes >= habit.goalValue {
//                 pauseTimer(save: true)
//             }
//             recompute()
//         }
//         RunLoop.main.add(timer!, forMode: .common)
//     }

//     func pauseTimer(save: Bool) {
//         UIImpactFeedbackGenerator(style: .light).impactOccurred()

//         isTimerRunning = false
//         timer?.invalidate()
//         timer = nil

//         if save, elapsedSeconds > 0 {
//             persistTimerSlice()
//         }

//         // reset ephemeral counters; persisted minutes are recomputed from Core Data
//         elapsedSeconds = 0
//         startDate = nil
//         recompute()
//     }

//     // Open full-screen focus UI
//     func expandToFocus() {
//         // optional: force start if not running and not complete
//         if habit.isTimerHabit, !habit.timerGoalMetToday, !isTimerRunning {
//             startTimer()
//         }
//         showFocusMode = true
//     }

//     // MARK: - Completion / coping

//     func completeOnce() {
//         let c = HabitCompletion(context: ctx)
//         c.id = UUID()
//         c.completedDate = Date()
//         c.habit = habit

//         habit.totalCompletions += 1
//         habit.lastCompletedDate = Date()
//         updateStreak()
//         try? ctx.save()
//     }

//     func completeCopingPlan() {
//         habit.completeCopingPlan()
//         try? ctx.save()
//     }

//     /// Toggle/complete a routine step and update stats if the routine is now complete today.
//     func toggleRoutineStep(at index: Int) {
//         guard habit.isRoutineHabit else { return }
//         UIImpactFeedbackGenerator(style: .light).impactOccurred()

//         let stepCompletion = HabitCompletion(context: ctx)
//         stepCompletion.id = UUID()
//         stepCompletion.completedDate = Date()
//         stepCompletion.habit = habit
//         stepCompletion.completedSteps = "\(index)"

//         let wasFullyCompleted = habit.updatedGoalMetToday
//         do { try ctx.save() } catch { print("Error saving step: \(error)") }
//         let isNowFullyCompleted = habit.updatedGoalMetToday
//         if !wasFullyCompleted && isNowFullyCompleted {
//             habit.totalCompletions += 1
//             habit.lastCompletedDate = Date()
//             updateStreak()
//             do { try ctx.save() } catch { print("Error saving habit stats after routine completion: \(error)") }
//         }
//         recompute()
//     }

//     /// For routine habits, complete the earliest incomplete step for today.
//     /// If all steps are already completed, does nothing.
//     func completeNextRoutineStep() {
//         guard habit.isRoutineHabit else { return }
//         let steps = habit.routineStepsArray
//         guard !steps.isEmpty else { return }

//         let completed = habit.completedStepsToday
//         // Find the smallest index that is not yet completed
//         if let nextIndex = (0..<steps.count).first(where: { !completed.contains($0) }) {
//             toggleRoutineStep(at: nextIndex)
//         }
//     }

//     // MARK: - Persistence for timer slices

//     private func persistTimerSlice() {
//         let minutes = elapsedSeconds / 60.0
//         guard minutes > 0 else { return }

//         let c = HabitCompletion(context: ctx)
//         c.id = UUID()
//         c.completedDate = Date()
//         c.habit = habit
//         c.timerDuration = minutes

//         // If goal crossed today for the first time, mark a completion for habit stats
//         let totalMinutesAfter = habit.timerMinutesToday + minutes
//         if totalMinutesAfter >= habit.goalValue && !habit.timerGoalMetToday {
//             habit.totalCompletions += 1
//             habit.lastCompletedDate = Date()
//             updateStreak()
//         }

//         try? ctx.save()
//     }

//     private func invalidateTimer() {
//         timer?.invalidate()
//         timer = nil
//         isTimerRunning = false
//     }

//     // MARK: - Derived UI

//     func recompute() {
//         // Progress percent/text and completion
//         if habit.isTimerHabit {
//             let total = habit.timerMinutesToday + elapsedSeconds / 60.0
//             let goal = max(habit.goalValue, 0.000001)
//             progressPercent = min(total / goal, 1.0)
//             progressText = timerRemainingText(totalMinutes: total, goalMinutes: goal)
//             isCompletedForDisplay = habit.timerGoalMetToday
//         } else if habit.isRoutineHabit {
//             progressPercent = habit.updatedRoutineProgressPercentage
//             progressText = "\(habit.routineProgress.completed)/\(habit.routineProgress.total) steps"
//             isCompletedForDisplay = habit.updatedGoalMetToday
//         } else if habit.isScheduledToday {
//             progressPercent = habit.progressPercentage
//             progressText = habit.currentProgressString
//             isCompletedForDisplay = habit.goalMetToday
//         } else {
//             let attempts = (habit.completions?.count ?? 0) > 0
//             progressPercent = attempts ? 1.0 : 0.0
//             progressText = attempts ? "1 attempt" : "0"
//             isCompletedForDisplay = attempts
//         }

//         // Main action button visuals
//         if habit.canUseCopingPlanToday {
//             mainButtonIcon = "heart.fill"
//             mainFillColor = Color.pink.opacity(0.1)
//             mainIconColor = .pink
//         } else if habit.isTimerHabit {
//             if habit.timerGoalMetToday {
//                 mainButtonIcon = "checkmark"
//                 mainFillColor = Color(hex: habit.colorHex ?? "#007AFF")
//                 mainIconColor = .white
//             } else {
//                 mainButtonIcon = isTimerRunning ? "pause.fill" : "play.fill"
//                 mainFillColor = Color(hex: habit.colorHex ?? "#007AFF").opacity(isTimerRunning ? 0.3 : 0.1)
//                 mainIconColor = Color(hex: habit.colorHex ?? "#007AFF")
//             }
//         } else if isCompletedForDisplay {
//             mainButtonIcon = "checkmark"
//             mainFillColor = Color(hex: habit.colorHex ?? "#007AFF")
//             mainIconColor = .white
//         } else {
//             mainButtonIcon = "plus"
//             mainFillColor = Color(hex: habit.colorHex ?? "#007AFF").opacity(0.1)
//             mainIconColor = Color(hex: habit.colorHex ?? "#007AFF")
//         }
//     }

//     private func timerRemainingText(totalMinutes: Double, goalMinutes: Double) -> String {
//         let remaining = max(0, (goalMinutes - totalMinutes) * 60.0)
//         let h = Int(remaining) / 3600
//         let m = (Int(remaining) % 3600) / 60
//         let s = Int(remaining) % 60
//         if remaining >= 3600 { return String(format: "%dh %dm left", h, m) }
//         if remaining >= 60   { return String(format: "%dm left", m) }
//         return String(format: "%ds left", s)
//     }

//     private func updateStreak() {
//         let cal = Calendar.current
//         let today = cal.startOfDay(for: Date())
//         if let last = habit.lastCompletedDate {
//             let d = cal.dateComponents([.day], from: cal.startOfDay(for: last), to: today).day ?? 0
//             if d == 1 { habit.currentStreak += 1 }
//             else if d > 1 { habit.currentStreak = 1 }
//         } else {
//             habit.currentStreak = 1
//         }
//         habit.longestStreak = max(habit.longestStreak, habit.currentStreak)
//     }
// }
