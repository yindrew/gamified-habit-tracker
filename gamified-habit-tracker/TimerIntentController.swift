//
//  TimerIntentController.swift
//  gamified-habit-tracker
//
//  Bridges AppIntentsKit ToggleHabitTimerIntent into the app runtime.
//

import Foundation
import CoreData
import AppIntentsKit

// Use an actor for thread safety and Sendable conformance
actor TimerIntentController: HabitTimerControlling {
    static let shared = TimerIntentController()

    private let context: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    private var managers: [String: HabitTimerManager] = [:] // habitId -> manager

    func toggleTimer(habitId: String, shouldRun: Bool) async {
        guard let uuid = UUID(uuidString: habitId) else { return }

        // Fetch (or refetch) the Habit on the main queue context
        let habit: Habit?
        do {
            habit = try fetchHabit(uuid: uuid)
        } catch {
            #if DEBUG
            print("[AppIntent] Failed to fetch habit: \(error)")
            #endif
            return
        }
        guard let habit = habit, habit.isTimerHabit else { return }

        // Prepare or reuse a manager for this habit
        let manager: HabitTimerManager = await managerForHabit(habit)

        // Dispatch side-effecting UI/timer actions onto main actor
        await MainActor.run {
            if shouldRun {
                // If already met goal, resume in overrun; else count toward goal.
                let totalElapsedMinutesToday = habit.timerMinutesToday
                let allowOverrun = habit.timerGoalMetToday || (totalElapsedMinutesToday >= habit.goalValue)
                manager.start(allowOverrun: allowOverrun, initialElapsed: totalElapsedMinutesToday * 60.0)
            } else {
                manager.pause(saveProgress: true)
            }
        }
    }

    // MARK: - Helpers
    private func fetchHabit(uuid: UUID) throws -> Habit? {
        let request = NSFetchRequest<Habit>(entityName: "Habit")
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        request.fetchLimit = 1
        let results = try context.fetch(request)
        return results.first
    }

    private func managerForHabit(_ habit: Habit) -> HabitTimerManager {
        let key = habit.id?.uuidString ?? ""
        if let existing = managers[key] { return existing }
        let mgr = HabitTimerManager(habit: habit, context: context)
        managers[key] = mgr
        return mgr
    }
}

