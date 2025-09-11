//
//  ChartDataBuilder.swift
//  gamified-habit-tracker
//
//  Helper to compute daily chart points for different habit types.
//

import Foundation

struct ChartDataPoint: Equatable, Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

enum ChartYAxis: String {
    case minutes = "minutes"
    case completions = "completions"
    case steps = "steps"
}

enum ChartDataBuilder {
    /// Build daily points for the given habit and completions.
    /// - Parameters:
    ///   - habit: The habit entity.
    ///   - completions: All completions for the habit (any date order).
    ///   - days: Optional day window (e.g., 7, 30, 90). If nil, computes from first completion or createdDate to `today`.
    ///   - today: Reference 'today' date (injectable for tests).
    /// - Returns: Points (ascending by date) and the y-axis label.
    static func dailyPoints(for habit: Habit,
                            completions: [HabitCompletion],
                            days: Int?,
                            today: Date = Date()) -> (points: [ChartDataPoint], yLabel: ChartYAxis) {
        let calendar = Calendar.current
        let startDate: Date
        if let d = days, d > 0 {
            startDate = calendar.date(byAdding: .day, value: -(d - 1), to: today) ?? today
        } else {
            // All time: use earliest available date
            let firstCompletion = completions.compactMap { $0.completedDate }.min()
            startDate = min(habit.createdDate ?? today, firstCompletion ?? today)
        }

        // Build list of days inclusive [startDate, today]
        var dayStarts: [Date] = []
        var d = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: today)
        while d <= end {
            dayStarts.append(d)
            d = calendar.date(byAdding: .day, value: 1, to: d) ?? end.addingTimeInterval(86400)
        }

        // Group completions per day
        var perDay: [Date: [HabitCompletion]] = [:]
        for c in completions {
            guard let dt = c.completedDate, dt >= startDate && dt <= today else { continue }
            let key = calendar.startOfDay(for: dt)
            perDay[key, default: []].append(c)
        }

        // Compute values
        let isTimer = habit.isTimerHabit
        let isRoutine = habit.isRoutineHabit
        let yAxis: ChartYAxis = isTimer ? .minutes : (isRoutine ? .steps : .completions)

        let points: [ChartDataPoint] = dayStarts.map { day in
            let comps = perDay[day] ?? []
            let val: Double
            if isTimer {
                // Sum minutes
                val = comps.reduce(0.0) { $0 + $1.timerDuration }
            } else if isRoutine {
                // Count unique step indices from completedSteps
                var set = Set<Int>()
                for c in comps {
                    if let s = c.completedSteps, !s.isEmpty {
                        let ints = s.split(separator: ",").compactMap { Int($0) }
                        set.formUnion(ints)
                    }
                }
                val = Double(set.count)
            } else {
                // Frequency: count completions
                val = Double(comps.count)
            }
            return ChartDataPoint(date: day, value: val)
        }

        return (points.sorted { $0.date < $1.date }, yAxis)
    }
}

