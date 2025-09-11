//
//  TimerHabitPersistenceTests.swift
//  gamified-habit-trackerTests
//
//  Verifies that timer habits persist and report minutes per day correctly,
//  including multiple segments in one day and across day boundaries.
//

import XCTest
import CoreData
@testable import gamified_habit_tracker

final class TimerHabitPersistenceTests: XCTestCase {
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

    private func makeTimerHabit(name: String = "Timer Habit", goalMinutes: Double = 30) -> Habit {
        let habit = Habit(context: context)
        habit.id = UUID()
        habit.name = name
        habit.habitType = "timer"
        habit.goalValue = goalMinutes // minutes
        habit.createdDate = Date()
        habit.isActive = true
        return habit
    }

    private func addTimerSegment(_ minutes: Double, to habit: Habit, at date: Date) {
        let c = HabitCompletion(context: context)
        c.id = UUID()
        c.completedDate = date
        c.habit = habit
        c.timerDuration = minutes
    }

    private func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    // Minutes for an arbitrary day (test-only helper to avoid relying on Date())
    private func timerMinutes(on day: Date, habit: Habit) -> Double {
        let dayStart = startOfDay(day)
        let next = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let dayCompletions = habit.completions?.filtered(using: NSPredicate(
            format: "completedDate >= %@ AND completedDate < %@",
            dayStart as NSDate, next as NSDate
        ))
        var total: Double = 0
        if let set = dayCompletions {
            for obj in set { if let hc = obj as? HabitCompletion { total += hc.timerDuration } }
        }
        return total
    }

    // MARK: - Tests

    func testTimerAccumulatesMultipleSegmentsSameDay() throws {
        let habit = makeTimerHabit(goalMinutes: 60)
        let today = Date()
        addTimerSegment(15, to: habit, at: today)
        addTimerSegment(20, to: habit, at: today)
        addTimerSegment(5, to: habit, at: today)

        // Direct day query
        XCTAssertEqual(timerMinutes(on: today, habit: habit), 40, accuracy: 0.001)

        // Uses production computed property for "today"
        XCTAssertEqual(habit.timerMinutesToday, 40, accuracy: 0.001)
        XCTAssertFalse(habit.timerGoalMetToday)
    }

    func testTimerMinutesSeparatedByDay() throws {
        let habit = makeTimerHabit(goalMinutes: 30)
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        addTimerSegment(10, to: habit, at: yesterday)
        addTimerSegment(5, to: habit, at: yesterday)
        addTimerSegment(25, to: habit, at: today)

        XCTAssertEqual(timerMinutes(on: yesterday, habit: habit), 15, accuracy: 0.001)
        XCTAssertEqual(timerMinutes(on: today, habit: habit), 25, accuracy: 0.001)

        // "Today" should not include yesterday's segments
        XCTAssertEqual(habit.timerMinutesToday, 25, accuracy: 0.001)
        XCTAssertFalse(habit.timerGoalMetToday) // goal 30 not yet reached
    }

    func testTimerGoalMetAndOverrun() throws {
        let habit = makeTimerHabit(goalMinutes: 30)
        let today = Date()

        addTimerSegment(20, to: habit, at: today)
        XCTAssertEqual(habit.timerMinutesToday, 20, accuracy: 0.001)
        XCTAssertFalse(habit.timerGoalMetToday)

        // Add another segment to cross the goal
        addTimerSegment(15, to: habit, at: today)
        XCTAssertEqual(habit.timerMinutesToday, 35, accuracy: 0.001)
        XCTAssertTrue(habit.timerGoalMetToday)
        
        addTimerSegment(15, to: habit, at: today)
        XCTAssertEqual(habit.timerMinutesToday, 50, accuracy: 0.001)
    }

    func testCompletionFrequencyPerDayWithTimerSegments() throws {
        // Even with timer segments, the raw completion count per day should be queryable.
        let habit = makeTimerHabit(goalMinutes: 10)
        let today = Date()
        let todayStart = startOfDay(today)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!

        // Add 3 segments today
        addTimerSegment(3, to: habit, at: today)
        addTimerSegment(4, to: habit, at: today)
        addTimerSegment(5, to: habit, at: today)

        let todayCompletions = habit.completions?.filtered(using: NSPredicate(
            format: "completedDate >= %@ AND completedDate < %@",
            todayStart as NSDate, tomorrowStart as NSDate
        ))

        XCTAssertEqual(todayCompletions?.count, 3)
        XCTAssertEqual(habit.timerMinutesToday, 12, accuracy: 0.001)
        XCTAssertTrue(habit.timerGoalMetToday) // goal 10
    }
}

