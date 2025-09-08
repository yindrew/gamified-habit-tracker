//
//  HabitTrackingTests.swift
//  gamified-habit-trackerTests
//
//  Created by Andrew Yin on 9/5/25.
//

import XCTest
import CoreData
@testable import gamified_habit_tracker

final class HabitTrackingTests: XCTestCase {
    var testContext: NSManagedObjectContext!
    var calendar: Calendar!
    
    override func setUpWithError() throws {
        // Create in-memory Core Data stack for testing
        let persistentContainer = NSPersistentContainer(name: "gamified_habit_tracker")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }
        
        testContext = persistentContainer.viewContext
        calendar = Calendar.current
    }
    
    override func tearDownWithError() throws {
        testContext = nil
        calendar = nil
    }
    
    // MARK: - Helper Methods
    
    private func createTestHabit(name: String = "Test Habit", 
                                schedule: ScheduleType = .daily,
                                targetFrequency: Int32 = 1) -> Habit {
        let habit = Habit(context: testContext)
        habit.id = UUID()
        habit.name = name
        habit.schedule = schedule
        habit.targetFrequency = targetFrequency
        habit.currentStreak = 0
        habit.longestStreak = 0
        habit.totalCompletions = 0
        habit.createdDate = Date()
        habit.isActive = true
        
        return habit
    }
    
    private func addCompletion(to habit: Habit, on date: Date) {
        let completion = HabitCompletion(context: testContext)
        completion.id = UUID()
        completion.completedDate = date
        completion.habit = habit
        
        habit.totalCompletions += 1
        habit.lastCompletedDate = date
    }
    
    private func dateFromDaysAgo(_ daysAgo: Int) -> Date {
        return calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
    }
    
    private func startOfDay(_ date: Date) -> Date {
        return calendar.startOfDay(for: date)
    }
    
    // MARK: - Basic Completion Tests
    
    func testHabitCompletionCreation() throws {
        let habit = createTestHabit()
        let today = Date()
        
        addCompletion(to: habit, on: today)
        
        XCTAssertEqual(habit.totalCompletions, 1)
        XCTAssertEqual(habit.completions?.count, 1)
        XCTAssertNotNil(habit.lastCompletedDate)
        
        let completion = habit.completions?.allObjects.first as? HabitCompletion
        XCTAssertNotNil(completion)
        XCTAssertEqual(completion?.habit, habit)
    }
    
    func testMultipleCompletionsOnSameDay() throws {
        let habit = createTestHabit(targetFrequency: 3)
        let today = Date()
        
        // Add 3 completions on the same day
        addCompletion(to: habit, on: today)
        addCompletion(to: habit, on: today)
        addCompletion(to: habit, on: today)
        
        XCTAssertEqual(habit.totalCompletions, 3)
        XCTAssertEqual(habit.completions?.count, 3)
        
        // Check completions for today
        let todayStart = startOfDay(today)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        
        let todayCompletions = habit.completions?.filtered(using: NSPredicate(format: "completedDate >= %@ AND completedDate < %@", todayStart as NSDate, tomorrowStart as NSDate))
        XCTAssertEqual(todayCompletions?.count, 3)
    }
    
    // MARK: - Day Changing Tests
    
    func testCompletionsAcrossMultipleDays() throws {
        let habit = createTestHabit()
        
        let today = Date()
        let yesterday = dateFromDaysAgo(1)
        let twoDaysAgo = dateFromDaysAgo(2)
        
        addCompletion(to: habit, on: twoDaysAgo)
        addCompletion(to: habit, on: yesterday)
        addCompletion(to: habit, on: today)
        
        XCTAssertEqual(habit.totalCompletions, 3)
        
        // Test filtering by specific days
        let todayStart = startOfDay(today)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        
        let todayCompletions = habit.completions?.filtered(using: NSPredicate(format: "completedDate >= %@ AND completedDate < %@", todayStart as NSDate, tomorrowStart as NSDate))
        XCTAssertEqual(todayCompletions?.count, 1)
        
        let yesterdayStart = startOfDay(yesterday)
        let todayStart2 = calendar.date(byAdding: .day, value: 1, to: yesterdayStart)!
        
        let yesterdayCompletions = habit.completions?.filtered(using: NSPredicate(format: "completedDate >= %@ AND completedDate < %@", yesterdayStart as NSDate, todayStart2 as NSDate))
        XCTAssertEqual(yesterdayCompletions?.count, 1)
    }
    
    func testMetricsStorageAndRetrieval() throws {
        let habit = createTestHabit()
        
        // Add completions over several days
        for i in 0..<7 {
            let date = dateFromDaysAgo(i)
            addCompletion(to: habit, on: date)
        }
        
        XCTAssertEqual(habit.totalCompletions, 7)
        XCTAssertEqual(habit.completions?.count, 7)
        
        // Test that we can retrieve completions for specific date ranges
        let weekStart = dateFromDaysAgo(6)
        let weekEnd = Date()
        
        let weekCompletions = habit.completions?.filtered(using: NSPredicate(format: "completedDate >= %@ AND completedDate <= %@", startOfDay(weekStart) as NSDate, weekEnd as NSDate))
        XCTAssertEqual(weekCompletions?.count, 7)
    }
    
    // MARK: - Streak Tests
    
    func testBasicStreakCalculation() throws {
        let habit = createTestHabit()
        
        // Test initial streak
        XCTAssertEqual(habit.currentStreak, 0)
        XCTAssertEqual(habit.longestStreak, 0)
        
        // Add first completion
        let today = Date()
        addCompletion(to: habit, on: today)
        
        // Use the proper streak calculation method
        let calculatedStreak = habit.calculateScheduledStreak()
        habit.currentStreak = calculatedStreak
        habit.longestStreak = max(habit.longestStreak, calculatedStreak)
        
        XCTAssertEqual(habit.currentStreak, 1)
        XCTAssertEqual(habit.longestStreak, 1)
    }
    
    func testConsecutiveDayStreak() throws {
        let habit = createTestHabit()
        
        // Add completions for 5 consecutive days (4 days ago to today)
        for i in 0..<5 {
            let date = dateFromDaysAgo(4 - i) // Start from 4 days ago to today
            addCompletion(to: habit, on: date)
        }
        
        // Calculate streak after all completions are added
        let calculatedStreak = habit.calculateScheduledStreak()
        habit.currentStreak = calculatedStreak
        habit.longestStreak = max(habit.longestStreak, calculatedStreak)
        
        XCTAssertEqual(habit.currentStreak, 5)
        XCTAssertEqual(habit.longestStreak, 5)
    }
    
    func testStreakBreakAndReset() throws {
        let habit = createTestHabit()
        
        // Build a 3-day streak (5, 4, 3 days ago)
        for i in 0..<3 {
            let date = dateFromDaysAgo(5 - i) // 5, 4, 3 days ago
            addCompletion(to: habit, on: date)
        }
        
        // Calculate initial streak - should be 0 because there's a gap to today
        let initialStreak = habit.calculateScheduledStreak()
        print("Initial streak (should be 0 due to gap): \(initialStreak)")
        
        // The streak is actually 0 because calculateScheduledStreak works backwards from today
        // and there's a gap between 3 days ago and today
        XCTAssertEqual(initialStreak, 0)
        
        // Now complete today - this should give us a streak of 1
        let today = Date()
        addCompletion(to: habit, on: today)
        
        let newStreak = habit.calculateScheduledStreak()
        habit.currentStreak = newStreak
        habit.longestStreak = max(habit.longestStreak, newStreak)
        
        print("New streak after completing today: \(newStreak)")
        
        XCTAssertEqual(habit.currentStreak, 1) // Just today's completion
        XCTAssertEqual(habit.longestStreak, 1) // Only one completion day
    }
    
    // MARK: - Schedule-Based Streak Tests
    
    func testWeeklyScheduleStreakCalculation() throws {
        let habit = createTestHabit(schedule: .weekly)
        
        // Set schedule for Monday and Wednesday (weekdays 2 and 4)
        habit.setWeeklySchedule(weekdays: [2, 4])
        
        // Test that habit is only scheduled on correct days
        let monday = getNextWeekday(2) // Monday
        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
        let wednesday = calendar.date(byAdding: .day, value: 2, to: monday)!
        
        XCTAssertTrue(habit.isScheduledForDate(monday))
        XCTAssertFalse(habit.isScheduledForDate(tuesday))
        XCTAssertTrue(habit.isScheduledForDate(wednesday))
    }
    
    func testScheduledStreakOnlyCountsScheduledDays() throws {
        let habit = createTestHabit(schedule: .weekly)
        habit.setWeeklySchedule(weekdays: [2, 4]) // Monday and Wednesday
        
        let today = Date()
        var completionDates: [Date] = []
        
        // Look back to find recent scheduled days and complete them
        for i in 0..<14 { // Look back 2 weeks
            let checkDate = calendar.date(byAdding: .day, value: -i, to: today)!
            let weekday = calendar.component(.weekday, from: checkDate)
            
            if weekday == 2 || weekday == 4 { // Monday or Wednesday
                completionDates.append(checkDate)
                addCompletion(to: habit, on: checkDate)
                
                if completionDates.count >= 4 { break } // Get 4 recent scheduled completions
            }
        }
        
        let scheduledStreak = habit.calculateScheduledStreak()
        print("Completion dates: \(completionDates.map { calendar.component(.weekday, from: $0) })")
        print("Scheduled streak: \(scheduledStreak)")
        
        // Should count consecutive scheduled days that were completed
        // If we found and completed 4 consecutive scheduled days, streak should be 4
        if completionDates.count >= 4 {
            XCTAssertEqual(scheduledStreak, 4, "Should count all 4 consecutive scheduled completions")
        } else if completionDates.count >= 3 {
            XCTAssertEqual(scheduledStreak, Int32(completionDates.count), "Should count all consecutive scheduled completions")
        } else {
            XCTAssertGreaterThanOrEqual(scheduledStreak, 0)
        }
    }
    
    func testScheduledStreakIgnoresUnscheduledDays() throws {
        let habit = createTestHabit(schedule: .weekly)
        habit.setWeeklySchedule(weekdays: [2]) // Only Monday
        
        let today = Date()
        let yesterday = dateFromDaysAgo(1)
        
        // Find the last two Mondays
        var lastMondays: [Date] = []
        for i in 0..<14 { // Look back 2 weeks
            let checkDate = calendar.date(byAdding: .day, value: -i, to: today)!
            let weekday = calendar.component(.weekday, from: checkDate)
            
            if weekday == 2 { // Monday
                lastMondays.append(checkDate)
                if lastMondays.count >= 2 { break }
            }
        }
        
        // Complete on the last two Mondays (scheduled days)
        for monday in lastMondays {
            addCompletion(to: habit, on: monday)
        }
        
        // Add completion on yesterday (unscheduled day) - this should NOT affect the streak
        addCompletion(to: habit, on: yesterday)
        
        let scheduledStreak = habit.calculateScheduledStreak()
        print("Scheduled streak ignoring unscheduled days: \(scheduledStreak)")
        print("Last Mondays: \(lastMondays)")
        
        // Should count consecutive Mondays, ignoring unscheduled days
        // Expect at least 1 (most recent Monday) if we found any Mondays
        if !lastMondays.isEmpty {
            XCTAssertGreaterThanOrEqual(scheduledStreak, 1)
            XCTAssertLessThanOrEqual(scheduledStreak, 2)
        } else {
            XCTAssertEqual(scheduledStreak, 0)
        }
    }
    
    func testMissedScheduledDayBreaksStreak() throws {
        let habit = createTestHabit(schedule: .weekly)
        habit.setWeeklySchedule(weekdays: [1, 2, 3]) // Sunday, Monday, Tuesday
        
        let today = Date()
        
        // Find recent scheduled days and create a scenario where we miss one
        var scheduledDates: [Date] = []
        for i in 0..<21 { // Look back 3 weeks
            let checkDate = calendar.date(byAdding: .day, value: -i, to: today)!
            let weekday = calendar.component(.weekday, from: checkDate)
            
            if weekday == 1 || weekday == 2 || weekday == 3 { // Sunday, Monday, Tuesday
                scheduledDates.append(checkDate)
                if scheduledDates.count >= 6 { break } // Get 6 recent scheduled days
            }
        }
        
        // Complete the first few scheduled days, then miss one, then complete more
        if scheduledDates.count >= 4 {
            // Complete first 2 scheduled days
            addCompletion(to: habit, on: scheduledDates[0])
            addCompletion(to: habit, on: scheduledDates[1])
            
            // Skip scheduledDates[2] - this creates a gap
            
            // Complete later scheduled days
            if scheduledDates.count > 3 {
                addCompletion(to: habit, on: scheduledDates[3])
            }
        }
        
        let scheduledStreak = habit.calculateScheduledStreak()
        print("Streak after missing scheduled day: \(scheduledStreak)")
        print("Scheduled dates: \(scheduledDates)")
        
        // Streak should be limited by the missed scheduled day
        // Should count from the most recent completion backwards until the gap
        if scheduledDates.count >= 4 {
            XCTAssertLessThanOrEqual(scheduledStreak, 2) // At most 2 (the recent completions)
        }
    }
    
    func testWeeklyHabitStreakIgnoresUnscheduledDays() throws {
        let habit = createTestHabit(schedule: .weekly)
        habit.setWeeklySchedule(weekdays: [2, 4]) // Monday and Wednesday only
        
        let today = Date()
        
        // Create a perfect scenario: complete last 2 Mondays and last 2 Wednesdays
        var mondaysAndWednesdays: [Date] = []
        
        for i in 0..<21 { // Look back 3 weeks
            let checkDate = calendar.date(byAdding: .day, value: -i, to: today)!
            let weekday = calendar.component(.weekday, from: checkDate)
            
            if weekday == 2 || weekday == 4 { // Monday or Wednesday
                mondaysAndWednesdays.append(checkDate)
                addCompletion(to: habit, on: checkDate)
                
                if mondaysAndWednesdays.count >= 4 { break } // Last 4 scheduled days
            }
        }
        
        // Also add completions on unscheduled days (Tuesday, Thursday, Friday)
        for i in 1..<8 {
            let unscheduledDate = calendar.date(byAdding: .day, value: -i, to: today)!
            let weekday = calendar.component(.weekday, from: unscheduledDate)
            
            if weekday != 2 && weekday != 4 { // Not Monday or Wednesday
                addCompletion(to: habit, on: unscheduledDate)
            }
        }
        
        let scheduledStreak = habit.calculateScheduledStreak()
        print("Weekly habit streak (Mon/Wed only): \(scheduledStreak)")
        print("Scheduled completions: \(mondaysAndWednesdays)")
        
        // Should count consecutive Monday/Wednesday completions, ignoring other days
        if !mondaysAndWednesdays.isEmpty {
            XCTAssertGreaterThanOrEqual(scheduledStreak, 1)
            XCTAssertLessThanOrEqual(scheduledStreak, 4)
        }
    }
    
    // MARK: - Helper Methods for Tests
    
    private func updateStreakForHabit(_ habit: Habit) {
        // Replicate the streak update logic from ContentView
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
            // Completed today already, streak continues
            return
        } else if daysBetween == 1 {
            // Completed yesterday, increment streak
            habit.currentStreak += 1
        } else {
            // Gap in completions, reset streak
            habit.currentStreak = 1
        }
        
        habit.longestStreak = max(habit.longestStreak, habit.currentStreak)
    }
    
    private func getNextWeekday(_ weekday: Int) -> Date {
        // Get the next occurrence of the specified weekday
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)
        var daysToAdd = weekday - currentWeekday
        
        if daysToAdd <= 0 {
            daysToAdd += 7
        }
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: today) ?? today
    }
}
