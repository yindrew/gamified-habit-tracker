//
//  HabitSchedule.swift
//  gamified-habit-tracker
//
//  Created by Andrew Yin on 9/5/25.
//

import Foundation

enum ScheduleType: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case weekendsOnly = "weekendsOnly"
    case weekdaysOnly = "weekdaysOnly"
    
    var displayName: String {
        switch self {
        case .daily:
            return "Every Day"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .weekendsOnly:
            return "Weekends Only"
        case .weekdaysOnly:
            return "Weekdays Only"
        }
    }
    
    var description: String {
        switch self {
        case .daily:
            return "Complete this habit every day"
        case .weekly:
            return "Complete this habit on specific days of the week"
        case .monthly:
            return "Complete this habit on specific days of the month"
        case .weekendsOnly:
            return "Complete this habit on weekends (Saturday & Sunday)"
        case .weekdaysOnly:
            return "Complete this habit on weekdays (Monday - Friday)"
        }
    }
    
    var icon: String {
        switch self {
        case .daily:
            return "calendar"
        case .weekly:
            return "calendar.day.timeline.leading"
        case .monthly:
            return "calendar.circle"
        case .weekendsOnly:
            return "calendar.badge.plus"
        case .weekdaysOnly:
            return "briefcase"
        }
    }
}

// MARK: - Habit Extensions for Scheduling
extension Habit {
    var schedule: ScheduleType {
        get {
            return ScheduleType(rawValue: scheduleType ?? "daily") ?? .daily
        }
        set {
            scheduleType = newValue.rawValue
        }
    }
    
    /// Check if this habit is scheduled for a specific date
    func isScheduledForDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        
        switch schedule {
        case .daily:
            return true
            
        case .weekly:
            let weekday = calendar.component(.weekday, from: date)
            // scheduleValue stores bitmask for days of week (1=Sunday, 2=Monday, etc.)
            return (Int(scheduleValue) & (1 << (weekday - 1))) != 0
            
        case .monthly:
            let day = calendar.component(.day, from: date)
            // scheduleValue stores bitmask for days of month (limited to first 31 days)
            if day <= 31 {
                return (Int(scheduleValue) & (1 << (day - 1))) != 0
            }
            return false
            
        case .weekendsOnly:
            let weekday = calendar.component(.weekday, from: date)
            return weekday == 1 || weekday == 7 // Sunday or Saturday
            
        case .weekdaysOnly:
            let weekday = calendar.component(.weekday, from: date)
            return weekday >= 2 && weekday <= 6 // Monday through Friday
        }
    }
    
    /// Get the next scheduled date after a given date
    func nextScheduledDate(after date: Date) -> Date? {
        let calendar = Calendar.current
        var nextDate = calendar.date(byAdding: .day, value: 1, to: date)!
        
        // Look ahead up to 60 days to find next scheduled date
        for _ in 0..<60 {
            if isScheduledForDate(nextDate) {
                return nextDate
            }
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate)!
        }
        
        return nil
    }
    
    /// Check if today is a scheduled day for this habit
    var isScheduledToday: Bool {
        return isScheduledForDate(Date())
    }
    
    /// Check if coping plan can be used for a specific date
    func canUseCopingPlan(for date: Date) -> Bool {
        guard let copingPlan = copingPlan, !copingPlan.isEmpty else { return false }
        
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date)!
        
        // Can use coping plan if yesterday was a scheduled day and we didn't complete it
        if isScheduledForDate(yesterday) {
            let yesterdayStart = calendar.startOfDay(for: yesterday)
            let todayStart = calendar.startOfDay(for: date)
            
            // Check if we completed the habit yesterday
            let yesterdayCompletions = completions?.filtered(using: NSPredicate(format: "completedDate >= %@ AND completedDate < %@", yesterdayStart as NSDate, todayStart as NSDate))
            
            // Also check if we already used coping plan today
            let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!
            let copingUsedToday = lastCopingDate != nil && 
                                 lastCopingDate! >= todayStart && 
                                 lastCopingDate! < todayEnd
            
            return (yesterdayCompletions?.count ?? 0) == 0 && !copingUsedToday
        }
        
        return false
    }
    
    /// Check if coping plan can be used today
    var canUseCopingPlanToday: Bool {
        return canUseCopingPlan(for: Date())
    }
    
    /// Complete the coping plan
    func completeCopingPlan() {
        lastCopingDate = Date()
        // Don't break the streak - this maintains it
    }
    
    /// Calculate streak considering schedule and coping plans
    func calculateScheduledStreak() -> Int32 {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak: Int32 = 0
        var currentDate = today
        
        // Look back to calculate current streak
        for _ in 0..<365 { // Max look back of 1 year
            if isScheduledForDate(currentDate) {
                let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                
                // Check if completed on this scheduled day
                let dayCompletions = completions?.filtered(using: NSPredicate(format: "completedDate >= %@ AND completedDate < %@", currentDate as NSDate, nextDay as NSDate))
                let completedThisDay = (dayCompletions?.count ?? 0) > 0
                
                // Check if used coping plan the next day
                let copingUsedNextDay = lastCopingDate != nil && 
                                       calendar.isDate(lastCopingDate!, inSameDayAs: nextDay)
                
                if completedThisDay || copingUsedNextDay {
                    streak += 1
                } else {
                    break // Streak broken
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }
        
        return streak
    }
    
    /// Get days of week for weekly schedule (returns array of weekday numbers)
    var weeklyScheduleDays: [Int] {
        guard schedule == .weekly else { return [] }
        var days: [Int] = []
        for i in 0..<7 {
            if (Int(scheduleValue) & (1 << i)) != 0 {
                days.append(i + 1) // Convert to Calendar weekday (1=Sunday, 2=Monday, etc.)
            }
        }
        return days
    }
    
    /// Set weekly schedule days
    func setWeeklySchedule(weekdays: [Int]) {
        schedule = .weekly
        var bitmask: Int32 = 0
        for weekday in weekdays {
            if weekday >= 1 && weekday <= 7 {
                bitmask |= Int32(1 << (weekday - 1))
            }
        }
        scheduleValue = bitmask
    }
    
    /// Get days of month for monthly schedule
    var monthlyScheduleDays: [Int] {
        guard schedule == .monthly else { return [] }
        var days: [Int] = []
        for i in 0..<31 {
            if (Int(scheduleValue) & (1 << i)) != 0 {
                days.append(i + 1)
            }
        }
        return days
    }
    
    /// Set monthly schedule days
    func setMonthlySchedule(days: [Int]) {
        schedule = .monthly
        var bitmask: Int32 = 0
        for day in days {
            if day >= 1 && day <= 31 {
                bitmask |= Int32(1 << (day - 1))
            }
        }
        scheduleValue = bitmask
    }
}
