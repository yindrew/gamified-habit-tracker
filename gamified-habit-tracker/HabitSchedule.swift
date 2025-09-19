//
//  HabitSchedule.swift
//  gamified-habit-tracker
//
//  Created by Andrew Yin on 9/5/25.
//

import Foundation
import CoreData

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
        if habitType == "ethereal" {
            return isActive
        }
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
        
        // Only allow coping plan for habits with at least 7-day streak
        guard currentStreak >= 7 else { return false }
        
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date)!
        
        // Only show coping plan if yesterday was a scheduled day and we didn't meet the threshold
        guard isScheduledForDate(yesterday) else { return false }
        
        // Don't show coping plan for habits created today or yesterday
        if let createdDate = createdDate {
            let createdStart = calendar.startOfDay(for: createdDate)
            let yesterdayStart = calendar.startOfDay(for: yesterday)
            if createdStart >= yesterdayStart {
                return false
            }
        }
        
        let yesterdayStart = calendar.startOfDay(for: yesterday)
        let todayStart = calendar.startOfDay(for: date)
        
        // Check if we met the target threshold yesterday
        let yesterdayCompletions = completions?.filtered(using: NSPredicate(format: "completedDate >= %@ AND completedDate < %@", yesterdayStart as NSDate, todayStart as NSDate)) as? Set<HabitCompletion>
        let completionCount = yesterdayCompletions?.filter { !$0.isJournalOnly }.count ?? 0
        let metThreshold = completionCount >= targetFrequency
        
        // Also check if we already used coping plan today
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        let copingUsedToday = lastCopingDate != nil && 
                             lastCopingDate! >= todayStart && 
                             lastCopingDate! < todayEnd
        
        // Prevent multiple coping plans within a short period (7 days cooldown)
        let copingCooldownViolated: Bool
        if let lastCoping = lastCopingDate {
            let daysSinceLastCoping = calendar.dateComponents([.day], from: lastCoping, to: date).day ?? 0
            copingCooldownViolated = daysSinceLastCoping < 7
        } else {
            copingCooldownViolated = false
        }
        
        // Coping plan available if threshold was missed, not used today, and not in cooldown
        return !metThreshold && !copingUsedToday && !copingCooldownViolated
    }
    
    /// Check if coping plan can be used today
    var canUseCopingPlanToday: Bool {
        return canUseCopingPlan(for: Date())
    }
    
    /// Complete the coping plan
    func completeCopingPlan() {
        lastCopingDate = Date()
        // Restore the streak by recalculating it with coping plan consideration
        currentStreak = calculateScheduledStreak()
        longestStreak = max(longestStreak, currentStreak)
    }
    
    /// Calculate streak considering schedule and coping plans
    func calculateScheduledStreak() -> Int32 {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak: Int32 = 0
        var currentDate = today
        
        // If we used coping plan today, start counting from yesterday
        // because coping plan covers yesterday's missed habit, not today's
        let copingUsedToday = lastCopingDate != nil && 
                             calendar.isDate(lastCopingDate!, inSameDayAs: today)
        
        if copingUsedToday {
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }
        
        // Look back to calculate current streak
        for _ in 0..<365 { // Max look back of 1 year
            if isScheduledForDate(currentDate) {
                let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                
                // Check if completed on this scheduled day
                let dayCompletions = completions?.filtered(using: NSPredicate(format: "completedDate >= %@ AND completedDate < %@", currentDate as NSDate, nextDay as NSDate)) as? Set<HabitCompletion>
                let actualCount = dayCompletions?.filter { !$0.isJournalOnly }.count ?? 0
                let completedThisDay = actualCount >= targetFrequency
                
                // Check if coping plan was used the next day to cover this missed day
                // (Coping plan used on day X covers the missed habit from day X-1)
                let copingUsedForThisDay = lastCopingDate != nil && 
                                          calendar.isDate(lastCopingDate!, inSameDayAs: nextDay)
                
                if completedThisDay || copingUsedForThisDay {
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
    
    // MARK: - Metric Helpers
    
    /// Current progress in metric units for today
    var currentProgress: Double {
        if isTimerHabit {
            return timerMinutesToday
        }
        if isRoutineHabit {
            let progress = routineProgress
            guard progress.total > 0 else { return 0.0 }
            return Double(progress.completed) / Double(progress.total) * goalValue
        }
        return frequencyMetricProgressToday
    }

    /// Current progress as formatted string with unit
    var currentProgressString: String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = allowsFractionalMetrics ? 1 : 0

        let progressStr = formatter.string(from: NSNumber(value: currentProgress)) ?? "0"
        let goalStr = formatter.string(from: NSNumber(value: goalValue)) ?? "0"

        return "\(progressStr)/\(goalStr) \(metricUnit ?? "times")"
    }
    
    /// Progress percentage for display
    var progressPercentage: Double {
        guard goalValue > 0 else { return 0.0 }
        return min(currentProgress / goalValue, 1.0)
    }

    /// Whether the goal has been met today
    var goalMetToday: Bool {
        return currentProgress >= goalValue
    }

    /// Completions today
    private var completionsToday: Int32 {
        Int32(todaysCompletions.count)
    }

    private var todaysCompletions: [HabitCompletion] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let predicate = NSPredicate(format: "completedDate >= %@ AND completedDate < %@", today as NSDate, tomorrow as NSDate)
        guard let todayCompletions = completions?.filtered(using: predicate) as? Set<HabitCompletion> else { return [] }
        return todayCompletions.filter { !$0.isJournalOnly }
    }

    var frequencyMetricProgressToday: Double {
        todaysCompletions.reduce(0) { running, completion in
            let amount = completion.metricAmount
            if amount > 0 {
                return running + amount
            }
            return running + metricValue
        }
    }

    var allowsFractionalMetrics: Bool {
        if isTimerHabit { return true }
        if isRoutineHabit { return false }
        return metricValue.truncatingRemainder(dividingBy: 1) != 0 || todaysCompletions.contains { $0.metricAmount > 0 && $0.metricAmount.truncatingRemainder(dividingBy: 1) != 0 }
    }
    
    // MARK: - Routine Habit Support
    
    /// Whether this is a routine habit
    var isRoutineHabit: Bool {
        return habitType == "routine"
    }
    
    /// Whether this is a timer habit
    var isTimerHabit: Bool {
        return habitType == "timer"
    }
    
    /// Whether this is an ethereal (single-shot) habit
    var isEtherealHabit: Bool {
        return habitType == "ethereal"
    }
    
    /// Get routine steps as array
    var routineStepsArray: [String] {
        guard isRoutineHabit, let stepsString = routineSteps else { return [] }
        return stepsString.components(separatedBy: "|||").filter { !$0.isEmpty }
    }
    
    /// For routine habits, override progress calculation
    var routineProgressPercentage: Double {
        guard isRoutineHabit else { return progressPercentage }
        // For now, routine habits are either 0% or 100% complete
        return goalMetToday ? 1.0 : 0.0
    }
    
    /// For routine habits, display completion status
    var routineProgressString: String {
        guard isRoutineHabit else { return currentProgressString }
        return goalMetToday ? "Completed" : "Not completed"
    }
    
    /// Get completed steps for today
    var completedStepsToday: Set<Int> {
        guard isRoutineHabit else { return [] }
        
        let todayCompletions = todaysCompletions
        var completedSteps: Set<Int> = []
        for completion in todayCompletions {
            if let stepsString = completion.completedSteps {
                let steps = stepsString.components(separatedBy: ",").compactMap { Int($0) }
                completedSteps.formUnion(steps)
            }
        }

        return completedSteps
    }
    
    /// Get routine progress as completed/total steps
    var routineProgress: (completed: Int, total: Int) {
        guard isRoutineHabit else { return (0, 0) }
        let total = routineStepsArray.count
        let completed = completedStepsToday.count
        return (completed, total)
    }
    
    /// Updated progress percentage for routine habits
    var updatedRoutineProgressPercentage: Double {
        guard isRoutineHabit else { return progressPercentage }
        let progress = routineProgress
        guard progress.total > 0 else { return 0.0 }
        return Double(progress.completed) / Double(progress.total)
    }
    
    /// Updated goal met for routine habits
    var updatedGoalMetToday: Bool {
        guard isRoutineHabit else { return goalMetToday }
        let progress = routineProgress
        return progress.completed == progress.total && progress.total > 0
    }
    
    // MARK: - Timer Habit Support
    
    /// Get total timer minutes completed today
    var timerMinutesToday: Double {
        guard isTimerHabit else { return 0.0 }
        
        let todayCompletions = todaysCompletions

        var totalMinutes: Double = 0.0
        for completion in todayCompletions {
            totalMinutes += completion.timerDuration
        }

        return totalMinutes
    }
    
    /// Timer progress percentage
    var timerProgressPercentage: Double {
        guard isTimerHabit && goalValue > 0 else { return 0.0 }
        return min(timerMinutesToday / goalValue, 1.0)
    }
    
    /// Timer progress string
    var timerProgressString: String {
        guard isTimerHabit else { return currentProgressString }
        let completed = timerMinutesToday
        let goal = goalValue
        
        let completedHours = Int(completed / 60)
        let completedMins = Int(completed.truncatingRemainder(dividingBy: 60))
        let goalHours = Int(goal / 60)
        let goalMins = Int(goal.truncatingRemainder(dividingBy: 60))
        
        let completedStr: String
        if completedHours > 0 {
            completedStr = completedMins > 0 ? "\(completedHours)h \(completedMins)m" : "\(completedHours)h"
        } else {
            completedStr = "\(completedMins)m"
        }
        
        let goalStr: String
        if goalHours > 0 {
            goalStr = goalMins > 0 ? "\(goalHours)h \(goalMins)m" : "\(goalHours)h"
        } else {
            goalStr = "\(goalMins)m"
        }
        
        return "\(completedStr) / \(goalStr)"
    }
    
    /// Whether timer goal is met today
    var timerGoalMetToday: Bool {
        guard isTimerHabit else { return goalMetToday }
        return timerMinutesToday >= goalValue
    }
}
