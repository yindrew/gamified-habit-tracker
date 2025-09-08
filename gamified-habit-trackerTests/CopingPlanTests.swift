//
//  CopingPlanTests.swift
//  gamified-habit-trackerTests
//
//  Created by Andrew Yin on 9/5/25.
//

import XCTest
import CoreData
@testable import gamified_habit_tracker

final class CopingPlanTests: XCTestCase {
    var testContext: NSManagedObjectContext!
    var calendar: Calendar!
    
    override func setUpWithError() throws {
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
    
    private func createTestHabit(schedule: ScheduleType = .daily, 
                                copingPlan: String? = "Do 5 push-ups instead") -> Habit {
        let habit = Habit(context: testContext)
        habit.id = UUID()
        habit.name = "Test Habit"
        habit.schedule = schedule
        habit.targetFrequency = 1
        habit.currentStreak = 0
        habit.longestStreak = 0
        habit.totalCompletions = 0
        habit.createdDate = Date()
        habit.isActive = true
        habit.copingPlan = copingPlan
        
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
    
    // MARK: - Basic Coping Plan Tests
    
    func testCopingPlanAvailability() throws {
        let habit = createTestHabit()
        
        // Set creation date to 10 days ago so it's not a new habit
        let tenDaysAgo = dateFromDaysAgo(10)
        habit.createdDate = tenDaysAgo
        
        // Set streak to 7 to meet minimum requirement
        habit.currentStreak = 7
        
        // Yesterday was scheduled but threshold was missed (0 < 1)
        // Coping plan should be available today
        XCTAssertTrue(habit.canUseCopingPlanToday)

        // Complete yesterday to meet threshold, making coping plan unavailable today
        let yesterday = dateFromDaysAgo(1)
        addCompletion(to: habit, on: yesterday)
        
        // Now coping plan should not be available since threshold was met
        XCTAssertFalse(habit.canUseCopingPlanToday)
    }
    
    func testCopingPlanNotAvailableWithoutPlan() throws {
        let habit = createTestHabit(copingPlan: nil) // No coping plan set
        
        XCTAssertFalse(habit.canUseCopingPlanToday)
    }
    
    func testCopingPlanNotAvailableWithEmptyPlan() throws {
        let habit = createTestHabit(copingPlan: "") // Empty coping plan
        
        XCTAssertFalse(habit.canUseCopingPlanToday)
    }
    
    func testCopingPlanNotAvailableForNewHabits() throws {
        let habit = createTestHabit()
        
        // Habit created today - coping plan should not be available
        XCTAssertFalse(habit.canUseCopingPlanToday)
        
        // Even if we set creation date to yesterday
        let yesterday = dateFromDaysAgo(1)
        habit.createdDate = yesterday
        XCTAssertFalse(habit.canUseCopingPlanToday)
        
        // Even when created 2+ days ago, need 7-day streak
        let twoDaysAgo = dateFromDaysAgo(2)
        habit.createdDate = twoDaysAgo
        XCTAssertFalse(habit.canUseCopingPlanToday) // Still no streak
        
        // Only with 7+ day streak should it be available
        habit.currentStreak = 7
        XCTAssertTrue(habit.canUseCopingPlanToday)
        
        habit.currentStreak = 10
        XCTAssertTrue(habit.canUseCopingPlanToday) // More than 7 days
    }
    
    
    func testCopingPlanCompletion() throws {
        let habit = createTestHabit()
        let today = Date()
        
        XCTAssertNil(habit.lastCopingDate)
        
        habit.completeCopingPlan()
        
        XCTAssertNotNil(habit.lastCopingDate)
        
        // Should be completed today
        let copingDate = habit.lastCopingDate!
        XCTAssertTrue(calendar.isDate(copingDate, inSameDayAs: today))
        XCTAssertFalse(habit.canUseCopingPlanToday)

    }
    
    // MARK: - Weekly Schedule Coping Plan Tests
    
    func testCopingPlanWithWeeklySchedule() throws {
        let habit = createTestHabit(schedule: .weekly)
        habit.currentStreak = 7
        habit.setWeeklySchedule(weekdays: [2]) // Only Monday
        
        let monday = getNextWeekday(2)
        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
        let wednesday = calendar.date(byAdding: .day, value: 2, to: monday)!
        
        // Miss Monday, coping plan should be available Tuesday
        XCTAssertTrue(habit.canUseCopingPlan(for: tuesday))
        
        // But not available Wednesday (too late)
        XCTAssertFalse(habit.canUseCopingPlan(for: wednesday))
    }
    
    func testCopingPlanNotAvailableAfterUnscheduledDay() throws {
        let habit = createTestHabit(schedule: .weekly)
        habit.setWeeklySchedule(weekdays: [2]) // Only Monday
        
        let sunday = getNextWeekday(1)
        let monday = calendar.date(byAdding: .day, value: 1, to: sunday)!
        
        // Sunday is not scheduled, so coping plan should not be available Monday
        XCTAssertFalse(habit.canUseCopingPlan(for: monday))
    }
    
    // MARK: - Coping Plan and Streak Interaction Tests
    
    func testCopingPlanRestoresStreak() throws {
        let habit = createTestHabit()
        
        // Set creation date to make it not a new habit
        habit.createdDate = dateFromDaysAgo(10)
        
        // Build a streak: complete 3 days ago and 2 days ago
        let threeDaysAgo = dateFromDaysAgo(3)
        let twoDaysAgo = dateFromDaysAgo(2)
        
        addCompletion(to: habit, on: threeDaysAgo)
        addCompletion(to: habit, on: twoDaysAgo)
        
        // Set an initial streak (8 days meets the 7+ requirement)
        habit.currentStreak = 8
        habit.longestStreak = 8
        
        // Miss yesterday (threshold not met), coping plan should be available
        XCTAssertTrue(habit.canUseCopingPlanToday, "Coping plan should be available")
        
        // Check what the calculated streak is before using coping plan
        let streakBefore = habit.calculateScheduledStreak()
        print("Streak before coping plan: \(streakBefore)")
        
        // Use coping plan today - this should restore/maintain the streak
        habit.completeCopingPlan()
        
        // Streak should be maintained/restored
        XCTAssertGreaterThan(habit.currentStreak, 0, "Current streak should be greater than 0")
        XCTAssertEqual(habit.currentStreak, 3)
        XCTAssertGreaterThanOrEqual(habit.longestStreak, habit.currentStreak, "Longest streak should be >= current streak")
    }
    

    // MARK: - Edge Cases
    
    func testCopingPlanAcrossDateBoundaries() throws {
        let habit = createTestHabit()
        
        // Test coping plan availability at different times of day
        let calendar = Calendar.current
        let today = Date()
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: today)!
        let startOfDay = calendar.startOfDay(for: today)
        
        XCTAssertEqual(habit.canUseCopingPlan(for: startOfDay), habit.canUseCopingPlan(for: endOfDay))
    }
    
    func testCopingPlanAfterRegularCompletion() throws {
        let habit = createTestHabit()
        let yesterday = dateFromDaysAgo(1)
        let today = Date()
        
        // Complete yesterday normally
        addCompletion(to: habit, on: yesterday)
        
        // Coping plan should not be available today
        XCTAssertFalse(habit.canUseCopingPlan(for: today))
    }
    
    
    func testCopingPlanWithDifferentTargetFrequencies() throws {
        let habit = createTestHabit()
        habit.createdDate = dateFromDaysAgo(10)

        habit.targetFrequency = 3 // Need 3 completions per day
        // Set streak to 7 to meet minimum requirement
        habit.currentStreak = 7
        let yesterday = dateFromDaysAgo(1)
        let today = Date()
        
        // Only complete once yesterday (1 < 3, threshold not met)
        addCompletion(to: habit, on: yesterday)
        
        // Coping plan should be available because target threshold wasn't met
        XCTAssertTrue(habit.canUseCopingPlan(for: today))
    }
    
    func testCopingPlanWithPartialCompletions() throws {
        let habit = createTestHabit()
        habit.targetFrequency = 3
        habit.currentStreak = 7
        habit.createdDate = dateFromDaysAgo(10)

        let yesterday = dateFromDaysAgo(1)
        let today = Date()
        
        // Complete twice yesterday (partial completion: 2 < 3)
        addCompletion(to: habit, on: yesterday)
        addCompletion(to: habit, on: yesterday)
        
        // Since target frequency is 3 but only completed twice, coping plan should be available
        XCTAssertTrue(habit.canUseCopingPlan(for: today))
    }
    
    func testCopingPlanWithExactThresholdMet() throws {
        let habit = createTestHabit()
        habit.targetFrequency = 2
        habit.currentStreak = 7
        habit.createdDate = dateFromDaysAgo(10)

        let yesterday = dateFromDaysAgo(1)
        let today = Date()
        
        // Complete exactly the target frequency yesterday
        addCompletion(to: habit, on: yesterday)
        addCompletion(to: habit, on: yesterday)
        
        // Since threshold was met exactly, coping plan should NOT be available
        XCTAssertFalse(habit.canUseCopingPlan(for: today))
    }
    
    func testCopingPlanWithExceededThreshold() throws {
        let habit = createTestHabit()
        habit.targetFrequency = 2
        habit.currentStreak = 7
        habit.createdDate = dateFromDaysAgo(10)

        let yesterday = dateFromDaysAgo(1)
        let today = Date()
        
        // Complete more than target frequency yesterday
        addCompletion(to: habit, on: yesterday)
        addCompletion(to: habit, on: yesterday)
        addCompletion(to: habit, on: yesterday)
        
        // Since threshold was exceeded, coping plan should NOT be available
        XCTAssertFalse(habit.canUseCopingPlan(for: today))
    }
    
    // MARK: - Helper Methods
    
    private func getNextWeekday(_ weekday: Int) -> Date {
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)
        var daysToAdd = weekday - currentWeekday
        
        if daysToAdd <= 0 {
            daysToAdd += 7
        }
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: today) ?? today
    }
    
    func testCopingPlanCooldownPreventsMultipleUses() throws {
        let habit = createTestHabit()
        habit.createdDate = dateFromDaysAgo(20)
        habit.currentStreak = 10
        habit.longestStreak = 10
        
        print("=== SCENARIO: Coping Plan Cooldown ===")
        
        // Use coping plan 5 days ago
        habit.lastCopingDate = dateFromDaysAgo(5)
        
        // Try to use coping plan today (within 7-day cooldown)
        // Should be blocked due to cooldown
        XCTAssertFalse(habit.canUseCopingPlanToday, "Coping plan should be blocked by 7-day cooldown")
        
        // Simulate using coping plan 8 days ago (outside cooldown)
        habit.lastCopingDate = dateFromDaysAgo(8)
        
        // Now coping plan should be available (if other conditions are met)
        // Note: This will depend on whether yesterday was missed
        let availability = habit.canUseCopingPlanToday
        print("Coping plan available after 8-day gap: \(availability)")
    }
    
    func testSingleCopingPlanInStreak() throws {
        let habit = createTestHabit()
        habit.createdDate = dateFromDaysAgo(20)
        
        // Build a streak with actual completions
        addCompletion(to: habit, on: dateFromDaysAgo(5))
        addCompletion(to: habit, on: dateFromDaysAgo(4))
        addCompletion(to: habit, on: dateFromDaysAgo(3))
        // Miss 2 days ago
        addCompletion(to: habit, on: dateFromDaysAgo(1)) // yesterday completed
        
        // Set initial streak
        habit.currentStreak = 8
        habit.longestStreak = 8
        
        // Use coping plan today to cover 2 days ago miss
        habit.lastCopingDate = Date()
        
        let calculatedStreak = habit.calculateScheduledStreak()
        print("Calculated streak with single coping plan: \(calculatedStreak)")
        
        // Should maintain streak continuity
        XCTAssertGreaterThan(calculatedStreak, 0, "Single coping plan should maintain streak")
    }
}
