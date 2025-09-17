//
//  IncrementHabitIntent.swift
//  gamified-habit-tracker
//
//  Handles widget/app intent requests to increment non-timer habits.
//

import AppIntents
import CoreData
import WidgetKit

@available(iOS 17.0, *)
public struct IncrementHabitIntent: AppIntent {
    public static var title: LocalizedStringResource { "Increment Habit" }
    public static var description = IntentDescription("Increase today's progress for a habit.")
    public static var openAppWhenRun: Bool { false }

    @Parameter(title: "Habit ID")
    public var habitId: String

    public init() {
        habitId = ""
    }

    public init(habitId: String) {
        self.habitId = habitId
    }

    public func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: habitId) else { return .result() }
        let context = PersistenceController.shared.container.viewContext

        try await context.perform {
            let request = NSFetchRequest<Habit>(entityName: "Habit")
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            request.fetchLimit = 1
            guard let habit = try context.fetch(request).first else { return }
            guard !habit.isTimerHabit else { return }

            let completion = HabitCompletion(context: context)
            completion.id = UUID()
            completion.completedDate = Date()
            completion.habit = habit

            habit.totalCompletions += 1
            habit.lastCompletedDate = Date()
            habit.currentStreak = habit.calculateScheduledStreak()
            habit.longestStreak = max(habit.longestStreak, habit.currentStreak)

            try context.save()
            HabitWidgetExporter.shared.scheduleSync(using: context)
        }

        await WidgetCenter.shared.reloadTimelines(ofKind: "timerVisual")
        return .result()
    }
}
