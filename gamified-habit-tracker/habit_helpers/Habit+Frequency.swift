extension Habit {

    var isFrequencyHabit: Bool {
        return habitType == "frequency"
    }

    var isEtherealHabit: Bool {
        return habitType == "ethereal"
    }

    var frequencyMetricProgressToday: Double {
        todaysCompletions.reduce(0) { running, completion in
            return running + completion.metricAmount
        }
    }

    var frequencyGoalMetToday: Bool {
        guard isFrequencyHabit || isEtherealHabit else { return goalMetToday }
        let progress = frequencyMetricProgressToday
        return progress >= goalValue
    }
}