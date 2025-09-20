extension Habit {
    var isTimerHabit: Bool {
        return habitType == "timer"
    }

    /// Total timer minutes completed today
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