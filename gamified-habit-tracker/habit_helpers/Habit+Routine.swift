extension Habit {

    var isRoutineHabit: Bool {
        return habitType == "routine"
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
    var routineGoalMetToday: Bool {
        guard isRoutineHabit else { return goalMetToday }
        let progress = routineProgress
        return progress.completed == progress.total && progress.total > 0
    }
}