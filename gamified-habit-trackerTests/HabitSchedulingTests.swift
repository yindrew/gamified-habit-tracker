//
//  HabitSchedulingTests.swift
//  gamified-habit-trackerTests
//
//  Created by Andrew Yin on 9/5/25.
//

import XCTest
import CoreData
@testable import gamified_habit_tracker

final class HabitSchedulingTests: XCTestCase {
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
    
    private func createTestHabit(schedule: ScheduleType = .daily) -> Habit {
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
        
        return habit
    }
    
    private func dateFromDaysAgo(_ daysAgo: Int) -> Date {
        return calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
    }
    
    private func dateFromDaysFromNow(_ days: Int) -> Date {
        return calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }
    
    // MARK: - Daily Schedule Tests
    
    func testDailyScheduleAlwaysActive() throws {
        let habit = createTestHabit(schedule: .daily)
        
        let today = Date()
        let yesterday = dateFromDaysAgo(1)
        let tomorrow = dateFromDaysFromNow(1)
        
        XCTAssertTrue(habit.isScheduledForDate(today))
        XCTAssertTrue(habit.isScheduledForDate(yesterday))
        XCTAssertTrue(habit.isScheduledForDate(tomorrow))
        XCTAssertTrue(habit.isScheduledToday)
    }
    
    // MARK: - Weekly Schedule Tests
    
    func testWeeklyScheduleConfiguration() throws {
        let habit = createTestHabit(schedule: .weekly)
        
        // Set schedule for Monday, Wednesday, Friday (weekdays 2, 4, 6)
        habit.setWeeklySchedule(weekdays: [2, 4, 6])
        
        XCTAssertEqual(Set(habit.weeklyScheduleDays), Set([2, 4, 6]))
    }
    
    func testWeeklyScheduleActiveDays() throws {
        let habit = createTestHabit(schedule: .weekly)
        habit.setWeeklySchedule(weekdays: [1, 7]) // Sunday and Saturday (weekends)
        
        // Test over a full week
        let startDate = getNextWeekday(1) // Next Sunday
        
        for i in 0..<7 {
            let testDate = calendar.date(byAdding: .day, value: i, to: startDate)!
            let weekday = calendar.component(.weekday, from: testDate)
            let expectedScheduled = (weekday == 1 || weekday == 7) // Sunday or Saturday
            
            XCTAssertEqual(habit.isScheduledForDate(testDate), expectedScheduled,
                          "Day \(weekday) should be \(expectedScheduled ? "scheduled" : "not scheduled")")
        }
    }
    
    func testWeeklyScheduleEmptyConfiguration() throws {
        let habit = createTestHabit(schedule: .weekly)
        habit.setWeeklySchedule(weekdays: []) // No days selected
        
        let today = Date()
        XCTAssertFalse(habit.isScheduledForDate(today))
        XCTAssertEqual(habit.weeklyScheduleDays.count, 0)
    }
    
    // MARK: - Monthly Schedule Tests
    
    func testMonthlyScheduleConfiguration() throws {
        let habit = createTestHabit(schedule: .monthly)
        
        // Set schedule for 1st, 15th, and last day of month
        habit.setMonthlySchedule(days: [1, 15, 31])
        
        XCTAssertEqual(Set(habit.monthlyScheduleDays), Set([1, 15, 31]))
    }
    
    func testMonthlyScheduleActiveDays() throws {
        let habit = createTestHabit(schedule: .monthly)
        habit.setMonthlySchedule(days: [1, 15]) // 1st and 15th of each month
        
        // Test first day of month
        let firstOfMonth = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        XCTAssertTrue(habit.isScheduledForDate(firstOfMonth))
        
        // Test 15th of month
        let fifteenthOfMonth = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15))!
        XCTAssertTrue(habit.isScheduledForDate(fifteenthOfMonth))
        
        // Test other days
        let secondOfMonth = calendar.date(from: DateComponents(year: 2024, month: 1, day: 2))!
        XCTAssertFalse(habit.isScheduledForDate(secondOfMonth))
        
        let tenthOfMonth = calendar.date(from: DateComponents(year: 2024, month: 1, day: 10))!
        XCTAssertFalse(habit.isScheduledForDate(tenthOfMonth))
    }
    
    func testMonthlyScheduleInvalidDays() throws {
        let habit = createTestHabit(schedule: .monthly)
        habit.setMonthlySchedule(days: [32, 35, 40]) // Invalid days
        
        let today = Date()
        XCTAssertFalse(habit.isScheduledForDate(today))
    }
    
    // MARK: - Weekends Only Schedule Tests
    
    func testWeekendsOnlySchedule() throws {
        let habit = createTestHabit(schedule: .weekendsOnly)
        
        // Test over a full week starting from Sunday
        let startDate = getNextWeekday(1) // Next Sunday
        
        for i in 0..<7 {
            let testDate = calendar.date(byAdding: .day, value: i, to: startDate)!
            let weekday = calendar.component(.weekday, from: testDate)
            let isWeekend = (weekday == 1 || weekday == 7) // Sunday or Saturday
            
            XCTAssertEqual(habit.isScheduledForDate(testDate), isWeekend,
                          "Day \(weekday) weekend status should match schedule")
        }
    }
    
    // MARK: - Weekdays Only Schedule Tests
    
    func testWeekdaysOnlySchedule() throws {
        let habit = createTestHabit(schedule: .weekdaysOnly)
        
        // Test over a full week starting from Sunday
        let startDate = getNextWeekday(1) // Next Sunday
        
        for i in 0..<7 {
            let testDate = calendar.date(byAdding: .day, value: i, to: startDate)!
            let weekday = calendar.component(.weekday, from: testDate)
            let isWeekday = (weekday >= 2 && weekday <= 6) // Monday through Friday
            
            XCTAssertEqual(habit.isScheduledForDate(testDate), isWeekday,
                          "Day \(weekday) weekday status should match schedule")
        }
    }
    
    // MARK: - Next Scheduled Date Tests
    
    func testNextScheduledDateDaily() throws {
        let habit = createTestHabit(schedule: .daily)
        
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let nextScheduled = habit.nextScheduledDate(after: today)
        XCTAssertNotNil(nextScheduled)
        
        let nextScheduledDay = calendar.startOfDay(for: nextScheduled!)
        let expectedDay = calendar.startOfDay(for: tomorrow)
        
        XCTAssertEqual(nextScheduledDay, expectedDay)
    }
    
    func testNextScheduledDateWeekly() throws {
        let habit = createTestHabit(schedule: .weekly)
        habit.setWeeklySchedule(weekdays: [1]) // Only Sunday
        
        let today = Date()
        let nextScheduled = habit.nextScheduledDate(after: today)
        
        XCTAssertNotNil(nextScheduled)
        
        let weekday = calendar.component(.weekday, from: nextScheduled!)
        XCTAssertEqual(weekday, 1) // Should be Sunday
    }
    
    func testNextScheduledDateNoUpcomingDates() throws {
        let habit = createTestHabit(schedule: .weekly)
        habit.setWeeklySchedule(weekdays: []) // No days scheduled
        
        let today = Date()
        let nextScheduled = habit.nextScheduledDate(after: today)
        
        XCTAssertNil(nextScheduled)
    }
    
    // MARK: - Schedule Validation Tests
    
    func testScheduleTypeEnumCases() throws {
        XCTAssertEqual(ScheduleType.daily.rawValue, "daily")
        XCTAssertEqual(ScheduleType.weekly.rawValue, "weekly")
        XCTAssertEqual(ScheduleType.monthly.rawValue, "monthly")
        XCTAssertEqual(ScheduleType.weekendsOnly.rawValue, "weekendsOnly")
        XCTAssertEqual(ScheduleType.weekdaysOnly.rawValue, "weekdaysOnly")
    }
    
    func testScheduleTypeFromRawValue() throws {
        XCTAssertEqual(ScheduleType(rawValue: "daily"), .daily)
        XCTAssertEqual(ScheduleType(rawValue: "weekly"), .weekly)
        XCTAssertEqual(ScheduleType(rawValue: "monthly"), .monthly)
        XCTAssertEqual(ScheduleType(rawValue: "weekendsOnly"), .weekendsOnly)
        XCTAssertEqual(ScheduleType(rawValue: "weekdaysOnly"), .weekdaysOnly)
        XCTAssertNil(ScheduleType(rawValue: "invalid"))
    }
    
    // MARK: - Edge Cases
    
    func testScheduleAcrossMonthBoundaries() throws {
        let habit = createTestHabit(schedule: .monthly)
        habit.setMonthlySchedule(days: [31])
        
        // Test February (no 31st day)
        let februaryDate = calendar.date(from: DateComponents(year: 2024, month: 2, day: 28))!
        XCTAssertFalse(habit.isScheduledForDate(februaryDate))
        
        // Test March (has 31st day)
        let march31 = calendar.date(from: DateComponents(year: 2024, month: 3, day: 31))!
        XCTAssertTrue(habit.isScheduledForDate(march31))
    }
    
    func testScheduleWithLeapYear() throws {
        let habit = createTestHabit(schedule: .monthly)
        habit.setMonthlySchedule(days: [29])
        
        // Test February 29 in leap year (2024)
        let feb29LeapYear = calendar.date(from: DateComponents(year: 2024, month: 2, day: 29))!
        XCTAssertTrue(habit.isScheduledForDate(feb29LeapYear))
        
        // Test February 29 in non-leap year doesn't exist, so should be false for any Feb date
        let feb28NonLeapYear = calendar.date(from: DateComponents(year: 2023, month: 2, day: 28))!
        XCTAssertFalse(habit.isScheduledForDate(feb28NonLeapYear))
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
}
