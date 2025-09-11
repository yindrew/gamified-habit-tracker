//
//  HabitDetailChartTests.swift
//  gamified-habit-trackerTests
//
//  Tests that HabitDetailView/ChartDataBuilder produce correct daily values
//  for frequency, timer, and routine habits.
//

import XCTest
import CoreData
@testable import gamified_habit_tracker

final class HabitDetailChartTests: XCTestCase {
    var context: NSManagedObjectContext!
    var calendar: Calendar!

    override func setUpWithError() throws {
        let container = NSPersistentContainer(name: "gamified_habit_tracker")
        let desc = NSPersistentStoreDescription()
        desc.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [desc]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Failed to load in-memory store: \(error)") }
        }
        context = container.viewContext
        calendar = Calendar.current
    }

    override func tearDownWithError() throws {
        context = nil
        calendar = nil
    }

    // MARK: - Helpers

    private func day(_ base: Date, addDays: Int) -> Date {
        calendar.date(byAdding: .day, value: addDays, to: base) ?? base
    }

    private func startOfDay(_ d: Date) -> Date { calendar.startOfDay(for: d) }

    private func makeHabit(type: String, goal: Double = 1) -> Habit {
        let h = Habit(context: context)
        h.id = UUID()
        h.name = "H"
        h.habitType = type
        h.goalValue = goal
        h.createdDate = Date()
        h.isActive = true
        return h
    }

    private func addCompletion(habit: Habit, date: Date, timerMinutes: Double? = nil, completedSteps: String? = nil) {
        let c = HabitCompletion(context: context)
        c.id = UUID()
        c.completedDate = date
        c.habit = habit
        if let m = timerMinutes { c.timerDuration = m }
        if let s = completedSteps { c.completedSteps = s }
    }

    // MARK: - Tests

    func testFrequencyDailyCounts() throws {
        let today = startOfDay(Date())
        let habit = makeHabit(type: "count")
        // Day -1: 2 completions, Day 0: 1 completion
        addCompletion(habit: habit, date: day(today, addDays: -1))
        addCompletion(habit: habit, date: day(today, addDays: -1))
        addCompletion(habit: habit, date: today)

        let completions = try context.fetch(NSFetchRequest<HabitCompletion>(entityName: "HabitCompletion"))
        let built = ChartDataBuilder.dailyPoints(for: habit, completions: completions, days: 2, today: today)
        XCTAssertEqual(built.yLabel, .completions)
        XCTAssertEqual(built.points.count, 2)
        XCTAssertEqual(built.points[0].value, 2) // yesterday
        XCTAssertEqual(built.points[1].value, 1) // today
    }

    func testTimerDailyMinutes() throws {
        let today = startOfDay(Date())
        let habit = makeHabit(type: "timer", goal: 30)
        // Yesterday: 10 + 5, Today: 25
        addCompletion(habit: habit, date: day(today, addDays: -1), timerMinutes: 10)
        addCompletion(habit: habit, date: day(today, addDays: -1), timerMinutes: 5)
        addCompletion(habit: habit, date: today, timerMinutes: 25)

        let completions = try context.fetch(NSFetchRequest<HabitCompletion>(entityName: "HabitCompletion"))
        let built = ChartDataBuilder.dailyPoints(for: habit, completions: completions, days: 2, today: today)
        XCTAssertEqual(built.yLabel, .minutes)
        XCTAssertEqual(built.points[0].value, 15)
        XCTAssertEqual(built.points[1].value, 25)
    }

    func testRoutineDailyUniqueSteps() throws {
        let today = startOfDay(Date())
        let habit = makeHabit(type: "routine")
        // Yesterday: steps 0 and 1 (two entries, including duplicate of 1)
        addCompletion(habit: habit, date: day(today, addDays: -1), completedSteps: "0")
        addCompletion(habit: habit, date: day(today, addDays: -1), completedSteps: "1,1")
        // Today: step 2
        addCompletion(habit: habit, date: today, completedSteps: "2")

        let completions = try context.fetch(NSFetchRequest<HabitCompletion>(entityName: "HabitCompletion"))
        let built = ChartDataBuilder.dailyPoints(for: habit, completions: completions, days: 2, today: today)
        XCTAssertEqual(built.yLabel, .steps)
        XCTAssertEqual(built.points[0].value, 2) // unique steps 0,1
        XCTAssertEqual(built.points[1].value, 1) // unique step 2
    }
}

