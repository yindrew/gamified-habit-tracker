//
//  HabitDetailView.swift
//  gamified-habit-tracker
//
//  Created by Andrew Yin on 9/5/25.
//

import SwiftUI
import CoreData
import Charts

struct HabitDetailView: View {
    @ObservedObject var habit: Habit
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditHabit = false
    @State private var showingDeleteAlert = false
    @State private var currentMonth = Date()
    @State private var selectedTimePeriod: TimePeriod = .lastMonth
    
    enum TimePeriod: String, CaseIterable {
        case lastWeek = "Week"
        case lastMonth = "Month"
        case last3Months = "3 Months"
        case allTime = "All Time"
        
        var days: Int? {
            switch self {
            case .lastWeek: return 7
            case .lastMonth: return 30
            case .last3Months: return 90
            case .allTime: return nil
            }
        }
    }
    
    // Fetch completions for this habit
    @FetchRequest private var completions: FetchedResults<HabitCompletion>
    
    init(habit: Habit) {
        self.habit = habit
        // Use a safer predicate that handles potential nil values
        let habitPredicate = NSPredicate(format: "habit == %@ AND habit != nil", habit)
        self._completions = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \HabitCompletion.completedDate, ascending: false)],
            predicate: habitPredicate,
            animation: .default
        )
    }
    
    private var chartData: (points: [ChartDataPoint], label: String) {
        let array = Array(completions)
        let built = ChartDataBuilder.dailyPoints(for: habit, completions: array, days: selectedTimePeriod.days)
        // For frequency habits, scale counts by metricValue and relabel to metricUnit
        if !habit.isTimerHabit && !habit.isRoutineHabit {
            let scaled = built.points.map { ChartDataPoint(date: $0.date, value: $0.value * habit.metricValue) }
            let unit = (habit.metricUnit?.isEmpty == false) ? habit.metricUnit! : "times"
            return (scaled, unit)
        }
        return (built.points, built.yLabel.rawValue)
    }
    
    private var streakData: [StreakPeriod] {
        let calendar = Calendar.current
        var streaks: [StreakPeriod] = []
        var currentStreak: StreakPeriod?
        
        let sortedCompletions = completions.compactMap { $0.completedDate }.sorted()
        var previousDate: Date?
        
        for date in sortedCompletions {
            let dayStart = calendar.startOfDay(for: date)
            
            if let prevDate = previousDate {
                let daysBetween = calendar.dateComponents([.day], from: prevDate, to: dayStart).day ?? 0
                
                if daysBetween <= 1 {
                    // Continue or start streak
                    if currentStreak == nil {
                        currentStreak = StreakPeriod(startDate: prevDate, endDate: dayStart, length: 2)
                    } else {
                        currentStreak?.endDate = dayStart
                        currentStreak?.length += 1
                    }
                } else {
                    // Break in streak
                    if let streak = currentStreak {
                        streaks.append(streak)
                    }
                    currentStreak = nil
                }
            }
            
            previousDate = dayStart
        }
        
        if let streak = currentStreak {
            streaks.append(streak)
        }
        
        return streaks.filter { $0.length >= 3 } // Only show streaks of 3+ days
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with habit info
                habitHeaderView
                if !habit.isEtherealHabit {
                    // Statistics cards
                    statisticsCardsView
                    
                    // Calendar view
                    calendarView
                    
                    // Progress chart
                    if #available(iOS 16.0, *) {
                        progressChartView
                    }
                }

                journalLogSection

            
            }
            .padding()
        }
        // .navigationTitle(habit.name ?? "Habit Details")
        // .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit Item") {
                        showingEditHabit = true
                    }
                    
                    Button("Delete Item", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditHabit) {
            HabitFormView(mode: .edit(habit))
        }
        .alert("Delete Habit", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteHabit()
            }
        } message: {
            Text("Are you sure you want to delete this habit? This action cannot be undone.")
        }
    }
    
    private var habitHeaderView: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: habit.colorHex ?? "#007AFF").opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: habit.icon ?? "star")
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(habit.name ?? "Unnamed Habit")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let description = habit.habitDescription, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
               
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var statisticsCardsView: some View {
        let color = Color(hex: habit.colorHex ?? "#007AFF")
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            // Core metrics: times the target was reached
            StatCard(title: "Targets Met (All Time)", value: "\(targetsMetAllTime)", color: color)
            StatCard(title: "Targets Met (This Week)", value: "\(targetsMetThisWeek)", color: color)
            StatCard(title: "Current Streak", value: "\(habit.currentStreak) days", color: color)
            StatCard(title: "Longest Streak", value: "\(habit.longestStreak) days", color: color)

            // Extra metrics based on habit type
            if habit.isTimerHabit {
                StatCard(title: "Total Time Spent", value: formatMinutes(totalTimeSpentAllTime), color: color)
                StatCard(title: "Time Spent This Week", value: formatMinutes(timeSpentThisWeek), color: color)
            } else if !habit.isRoutineHabit {
                // Frequency habits: show metric totals using metricValue/unit
                let unit = (habit.metricUnit?.isEmpty == false) ? habit.metricUnit! : "times"
                let allTimeTotal = Double(completions.count) * habit.metricValue
                let weekTotal = Double(completionsThisWeek) * habit.metricValue
                StatCard(title: "Completed (All Time)", value: "\(formatMetricTotal(allTimeTotal)) \(unit)", color: color)
                StatCard(title: "Completed (This Week)", value: "\(formatMetricTotal(weekTotal)) \(unit)", color: color)
            }
        }
    }

    // MARK: - Statistics helpers
    private var targetsMetAllTime: Int {
        let calendar = Calendar.current
        // Group completions by day
        var perDay: [Date: [HabitCompletion]] = [:]
        for c in completions {
            guard let dt = c.completedDate else { continue }
            let key = calendar.startOfDay(for: dt)
            perDay[key, default: []].append(c)
        }
        return perDay.reduce(0) { acc, pair in
            acc + (isTargetMet(on: pair.key, with: pair.value) ? 1 : 0)
        }
    }

    private var targetsMetThisWeek: Int {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        // Group completions by day within this week
        var perDay: [Date: [HabitCompletion]] = [:]
        for c in completions {
            guard let dt = c.completedDate, dt >= weekStart else { continue }
            let key = calendar.startOfDay(for: dt)
            perDay[key, default: []].append(c)
        }
        return perDay.reduce(0) { acc, pair in
            acc + (isTargetMet(on: pair.key, with: pair.value) ? 1 : 0)
        }
    }

    private func isTargetMet(on day: Date, with dayCompletions: [HabitCompletion]) -> Bool {
        if habit.isTimerHabit {
            let minutes = dayCompletions.reduce(0.0) { $0 + $1.timerDuration }
            return minutes >= habit.goalValue
        } else if habit.isRoutineHabit {
            let totalSteps = habit.routineStepsArray.count
            guard totalSteps > 0 else { return false }
            var steps = Set<Int>()
            for c in dayCompletions {
                if let s = c.completedSteps, !s.isEmpty {
                    let ints = s.split(separator: ",").compactMap { Int($0) }
                    steps.formUnion(ints)
                }
            }
            return steps.count >= totalSteps
        } else {
            // Frequency: at least targetFrequency completions
            return dayCompletions.count >= Int(habit.targetFrequency)
        }
    }

    private var totalTimeSpentAllTime: Double {
        guard habit.isTimerHabit else { return 0 }
        return completions.reduce(0.0) { $0 + $1.timerDuration }
    }

    private var timeSpentThisWeek: Double {
        guard habit.isTimerHabit else { return 0 }
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return completions.filter { ($0.completedDate ?? .distantPast) >= weekStart }
            .reduce(0.0) { $0 + $1.timerDuration }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let totalSeconds = Int((minutes * 60).rounded())
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        if h > 0 {
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(m)m"
    }

    private func formatMetricTotal(_ total: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = habit.metricValue.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        return formatter.string(from: NSNumber(value: total)) ?? "0"
    }
    
    private var calendarView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Month navigation header
            HStack {
                Button(action: { changeMonth(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
                }
                
                Spacer()
                
                Text(monthYearFormatter.string(from: currentMonth))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { changeMonth(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
                }
            }
            .padding(.horizontal)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // Day headers
                ForEach(dayHeaders, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(height: 30)
                }
                
                // Calendar days
                ForEach(calendarDays, id: \.date) { calendarDay in
                    CalendarDayView(
                        day: calendarDay,
                        habitColor: Color(hex: habit.colorHex ?? "#007AFF")
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    @available(iOS 16.0, *)
    private var progressChartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress Chart")
                    .font(.headline)
                Spacer()
            }
            
            // Time period selector
            Picker("Time Period", selection: $selectedTimePeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Chart(chartData.points) { item in
                // Subtle fill under the line
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value(chartData.label, item.value)
                )
                .foregroundStyle(Color(hex: habit.colorHex ?? "#007AFF").opacity(0.12))

                // Line on top
                LineMark(
                    x: .value("Date", item.date),
                    y: .value(chartData.label, item.value)
                )
                .foregroundStyle(Color(hex: habit.colorHex ?? "#007AFF"))

                // Less prominent points
                PointMark(
                    x: .value("Date", item.date),
                    y: .value(chartData.label, item.value)
                )
                .symbolSize(20)
                .foregroundStyle(Color(hex: habit.colorHex ?? "#007AFF").opacity(0.6))
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: getXAxisValues()) { value in
                    AxisGridLine()
                    AxisValueLabel(format: getXAxisFormat())
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                    AxisGridLine()
                }
            }
            .chartYAxisLabel(chartData.label, position: .leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var journalLogSection: some View {
        Group {
            if journalEntries.isEmpty {
                journalEmptyState
            } else if #available(iOS 16.0, *) {
                journalSectionModern
            } else {
                journalSectionFallback
            }
        }
    }

    private var journalEntries: [HabitCompletion] {
        completions.compactMap { entry in
            let hasMood = entry.moodScore > 0
            let note = entry.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let hasNote = !note.isEmpty
            return (hasMood || hasNote) ? entry : nil
        }
        .sorted { (lhs, rhs) in
            (lhs.completedDate ?? .distantPast) > (rhs.completedDate ?? .distantPast)
        }
    }

    private var limitedJournalEntries: [HabitCompletion] {
        Array(journalEntries.prefix(10))
    }

    private var moodDataPoints: [MoodChartDataPoint] {
        journalEntries.compactMap { entry in
            guard entry.moodScore > 0, let date = entry.completedDate else { return nil }
            return MoodChartDataPoint(date: date, mood: Int(entry.moodScore))
        }
        .sorted { $0.date < $1.date }
    }

    private var journalEntriesList: some View {
        VStack(spacing: 12) {
            let entries = limitedJournalEntries
            ForEach(Array(entries.enumerated()), id: \.element.objectID) { index, entry in
                journalRow(for: entry)
                if index < entries.count - 1 {
                    Divider()
                }
            }
        }
    }

    private var journalEmptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reflections")
                    .font(.headline)
                Spacer()
            }
            Text("Complete the habit and add a journal entry to build a history of how the habit felt day to day.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @available(iOS 16.0, *)
    private var journalSectionModern: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Reflections")
                    .font(.headline)
                Spacer()
            }

            if !moodDataPoints.isEmpty {
                Chart(moodDataPoints) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Mood", point.mood)
                    )
                    .foregroundStyle(point.color.opacity(0.15))

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Mood", point.mood)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(point.color)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Mood", point.mood)
                    )
                    .symbolSize(40)
                    .foregroundStyle(point.color)
                }
                .chartYScale(domain: 1...5)
                .chartYAxis {
                    AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                        AxisGridLine()
                        AxisValueLabel(centered: true) {
                            if let moodScore = value.as(Int.self) {
                                Circle()
                                    .fill(MoodPalette.color(for: moodScore))
                                    .frame(width: 12, height: 12)
                                    .accessibilityLabel(Text(MoodPalette.label(for: moodScore)))
                            }
                        }
                    }
                }
                .chartYAxisLabel("Mood", position: .leading)
                .chartLegend(.hidden)
                .frame(height: 160)
            }

            journalEntriesList
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var journalSectionFallback: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Reflections")
                    .font(.headline)
                Spacer()
            }
            journalEntriesList
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func journalRow(for entry: HabitCompletion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let date = entry.completedDate {
                    Text(dateFormatter.string(from: date))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                let moodValue = max(1, min(5, Int(entry.moodScore)))
                if entry.moodScore > 0 {
                    Circle()
                        .fill(MoodPalette.color(for: moodValue))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle().stroke(Color.primary.opacity(0.25), lineWidth: 1)
                        )
                        .accessibilityLabel(Text("Mood \(moodValue)"))
                }
            }

            if let note = entry.notes, !note.isEmpty {
                Text(note)
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
    }

    private struct MoodChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let mood: Int
        var color: Color { MoodPalette.color(for: mood) }
    }

    @available(iOS 16.0, *)
    private func getXAxisValues() -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        // Get the total days for the selected period
        let totalDays: Int
        let startDate: Date
        
        switch selectedTimePeriod {
        case .lastWeek:
            totalDays = 7
            startDate = calendar.date(byAdding: .day, value: -6, to: today) ?? today
            
        case .lastMonth:
            totalDays = 30
            startDate = calendar.date(byAdding: .day, value: -29, to: today) ?? today
            
        case .last3Months:
            totalDays = 90
            startDate = calendar.date(byAdding: .day, value: -89, to: today) ?? today
            
        case .allTime:
            let habitStartDate = habit.createdDate ?? completions.last?.completedDate ?? today
            totalDays = calendar.dateComponents([.day], from: habitStartDate, to: today).day ?? 0
            startDate = habitStartDate
        }
        
        // Handle edge case for very short periods
        if totalDays <= 4 {
            var dates: [Date] = []
            for i in 0...totalDays {
                if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                    dates.append(date)
                }
            }
            return dates
        } else {
            // Show 4 equally spaced dates
            var dates: [Date] = []
            let interval = totalDays / 3
            for i in 0..<4 {
                if let date = calendar.date(byAdding: .day, value: (i * interval), to: startDate) {
                    dates.append(date)
                }
            }
            return dates
        }
    }
    
    @available(iOS 16.0, *)
    private func getXAxisFormat() -> Date.FormatStyle {
        switch selectedTimePeriod {
        case .lastWeek:
            return .dateTime.weekday(.abbreviated) // Mon, Wed, Thu, Sat
        case .lastMonth, .last3Months, .allTime:
            return .dateTime.month(.abbreviated).day() // Jan 15
        }
    }
    
    private var completionsThisWeek: Int {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        
        return completions.filter { completion in
            guard let date = completion.completedDate else { return false }
            return date >= weekStart
        }.count
    }
    
    private var dayHeaders: [String] {
        let formatter = DateFormatter()
        return formatter.shortWeekdaySymbols
    }
    
    private var calendarDays: [CalendarDay] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }
        
        let firstOfMonth = monthInterval.start
        let lastOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? monthInterval.end
        
        // Get the first day of the week for the first day of the month
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let startOffset = firstWeekday - 1 // Sunday = 1, so offset by 1 less
        
        var days: [CalendarDay] = []
        
        // Add empty days for the beginning of the month
        if startOffset > 0 {
            for i in 0..<startOffset {
                if let date = calendar.date(byAdding: .day, value: -startOffset + i, to: firstOfMonth) {
                    days.append(CalendarDay(date: date, isInCurrentMonth: false, completionCount: 0))
                }
            }
        }
        
        // Add days of the current month
        let daysInMonth = calendar.dateComponents([.day], from: firstOfMonth, to: lastOfMonth).day ?? 0
        for dayOffset in 0...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: firstOfMonth) {
                let status = getTargetStatusValue(for: date)
                days.append(CalendarDay(date: date, isInCurrentMonth: true, completionCount: status))
            }
        }
        
        // Add empty days to fill the last week
        let totalCells = 42 // 6 rows × 7 days
        while days.count < totalCells {
            if let lastDate = days.last?.date,
               let nextDate = calendar.date(byAdding: .day, value: 1, to: lastDate) {
                days.append(CalendarDay(date: nextDate, isInCurrentMonth: false, completionCount: 0))
            } else {
                break
            }
        }
        
        return Array(days.prefix(totalCells))
    }
    
    private func getCompletionCount(for date: Date) -> Int {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        return completions.filter { completion in
            guard let completedDate = completion.completedDate else { return false }
            return completedDate >= dayStart && completedDate < dayEnd
        }.count
    }

    private func getCompletions(for date: Date) -> [HabitCompletion] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        return completions.filter { c in
            guard let d = c.completedDate else { return false }
            return d >= dayStart && d < dayEnd
        }
    }

    // 0 = none, 1 = partial, 2 = met
    private func getTargetStatusValue(for date: Date) -> Int {
        // Only color scheduled days
        if !habit.isScheduledForDate(date) { return 0 }
        let dayComps = getCompletions(for: date)
        if isTargetMet(on: date, with: dayComps) { return 2 }
        // Partial if there is some progress but not met
        if habit.isTimerHabit {
            let minutes = dayComps.reduce(0.0) { $0 + $1.timerDuration }
            return minutes > 0 ? 1 : 0
        } else if habit.isRoutineHabit {
            let steps = dayComps.reduce(into: Set<Int>()) { acc, c in
                if let s = c.completedSteps, !s.isEmpty {
                    s.split(separator: ",").compactMap { Int($0) }.forEach { acc.insert($0) }
                }
            }
            return steps.count > 0 ? 1 : 0
        } else {
            return dayComps.count > 0 ? 1 : 0
        }
    }
    
    private func changeMonth(_ direction: Int) {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: direction, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func deleteHabit() {
        withAnimation {
            habit.isActive = false
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DailyCompletion: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct StreakPeriod {
    let startDate: Date
    var endDate: Date
    var length: Int
}

struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let isInCurrentMonth: Bool
    let completionCount: Int
}

struct CalendarDayView: View {
    let day: CalendarDay
    let habitColor: Color
    
    var body: some View {
        VStack {
            Text("\(Calendar.current.component(.day, from: day.date))")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(day.isInCurrentMonth ? .primary : .secondary)
        }
        .frame(width: 32, height: 32)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(day.completionCount > 0 ? habitColor : Color.clear)
                .opacity(
                    day.completionCount == 2 ? 1.0 :
                    (day.completionCount == 1 ? 0.5 : 0.0)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(habitColor.opacity(0.3), lineWidth: day.isInCurrentMonth ? 1 : 0)
        )
        .opacity(day.isInCurrentMonth ? 1.0 : 0.5)
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
}()

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
}()

private let monthYearFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter
}()

#Preview {
    NavigationView {
        let context = PersistenceController.preview.container.viewContext
        let habit = Habit(context: context)
        habit.name = "Sample Habit"
        habit.icon = "star"
        habit.colorHex = "#007AFF"
        habit.targetFrequency = 1
        habit.currentStreak = 5
        habit.longestStreak = 10
        habit.totalCompletions = 25
        habit.createdDate = Date()
        habit.isActive = true
        
        return HabitDetailView(habit: habit)
            .environment(\.managedObjectContext, context)
    }
}
