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
        // For frequency habits, ChartDataBuilder already returns metric totals; relabel axis to unit
        if !habit.isTimerHabit && !habit.isRoutineHabit {
            let unit = (habit.metricUnit?.isEmpty == false) ? habit.metricUnit! : "times"
            return (built.points, unit)
        }
        return (built.points, built.yLabel.rawValue)
    }

    private var timePeriodStartDate: Date? {
        guard let days = selectedTimePeriod.days, days > 0 else { return nil }
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -(days - 1), to: todayStart)
    }

    private var chartTimeBounds: ClosedRange<Date> {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: todayStart)?.addingTimeInterval(-1) ?? todayStart

        if let days = selectedTimePeriod.days, days > 0 {
            let start = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) ?? todayStart
            return start...endOfToday
        }

        let earliestPoint = chartData.points.first?.date ?? (habit.createdDate ?? todayStart)
        let start = calendar.startOfDay(for: earliestPoint)
        return start...endOfToday
    }

    private var habitDataStartDate: Date {
        let calendar = Calendar.current
        let created = habit.createdDate.map { calendar.startOfDay(for: $0) }
        let earliestCompletion = completions.compactMap { $0.completedDate }.min().map { calendar.startOfDay(for: $0) }
        return [created, earliestCompletion].compactMap { $0 }.min() ?? chartTimeBounds.lowerBound
    }

    private var progressPointsInWindow: [ChartDataPoint] {
        chartData.points.filter { $0.date >= chartTimeBounds.lowerBound && $0.date <= chartTimeBounds.upperBound }
    }

    private var progressDisplayPoints: [ChartDataPoint] {
        let displayStart = max(chartTimeBounds.lowerBound, habitDataStartDate)
        return chartData.points.filter { $0.date >= displayStart }
    }

    private var progressNoDataSegments: [NoDataSegment] {
        let calendar = Calendar.current
        let start = chartTimeBounds.lowerBound
        let end = chartTimeBounds.upperBound
        guard progressPointsInWindow.contains(where: { $0.value > 0 }) else {
            return [NoDataSegment(start: start, end: end)]
        }
        let dataStart = max(start, habitDataStartDate)
        guard dataStart > start else { return [] }
        let adjustedEnd = min(end, calendar.date(byAdding: .second, value: -1, to: dataStart) ?? dataStart)
        guard adjustedEnd > start else { return [] }
        return [NoDataSegment(start: start, end: adjustedEnd)]
    }

    private var moodNoDataSegments: [NoDataSegment] {
        let calendar = Calendar.current
        let start = chartTimeBounds.lowerBound
        let end = chartTimeBounds.upperBound
        guard let firstMoodDate = moodDataPoints.first?.date else {
            return [NoDataSegment(start: start, end: end)]
        }
        var segments: [NoDataSegment] = []
        let firstMoodDayStart = calendar.startOfDay(for: firstMoodDate)
        let dataStart = max(start, firstMoodDayStart)
        if dataStart > start {
            let adjustedEnd = min(end, calendar.date(byAdding: .second, value: -1, to: dataStart) ?? dataStart)
            if adjustedEnd > start {
                segments.append(NoDataSegment(start: start, end: adjustedEnd))
            }
        }
        return segments
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
    
    private var menuItemLabel: String {
        habit.isEtherealHabit ? "Task" : "Habit"
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
                    
                    // Shared time filter
                    timePeriodPickerView
                    
                    // Progress chart
                    if #available(iOS 16.0, *) {
                        progressChartView
                    }
                }
                
                reflectionsChartSection
                reflectionsLogSection
            }
            .padding()
        }
        // .navigationTitle(habit.name ?? "Habit Details")
        // .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit \(menuItemLabel)") {
                        showingEditHabit = true
                    }
                    
                    Button("Delete \(menuItemLabel)", role: .destructive) {
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
        .alert("Delete \(menuItemLabel)", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteHabit()
            }
        } message: {
            Text("Are you sure you want to delete this \(menuItemLabel.lowercased())? This action cannot be undone.")
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
                let allTimeTotal = metricTotal(for: Array(completions))
                let weekTotal = metricTotalThisWeek
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
        for c in completions where !c.isJournalOnly {
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
        for c in completions where !c.isJournalOnly {
            guard let dt = c.completedDate, dt >= weekStart else { continue }
            let key = calendar.startOfDay(for: dt)
            perDay[key, default: []].append(c)
        }
        return perDay.reduce(0) { acc, pair in
            acc + (isTargetMet(on: pair.key, with: pair.value) ? 1 : 0)
        }
    }

    private func isTargetMet(on day: Date, with dayCompletions: [HabitCompletion]) -> Bool {
        let relevantCompletions = dayCompletions.filter { !$0.isJournalOnly }

        if habit.isTimerHabit {
            let minutes = relevantCompletions.reduce(0.0) { $0 + $1.timerDuration }
            return minutes >= habit.goalValue
        } else if habit.isRoutineHabit {
            let totalSteps = habit.routineStepsArray.count
            guard totalSteps > 0 else { return false }
            var steps = Set<Int>()
            for c in relevantCompletions {
                if let s = c.completedSteps, !s.isEmpty {
                    let ints = s.split(separator: ",").compactMap { Int($0) }
                    steps.formUnion(ints)
                }
            }
            return steps.count >= totalSteps
        } else {
            // Frequency: at least targetFrequency completions
            return relevantCompletions.count >= Int(habit.targetFrequency)
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
        let chartColor = Color(hex: habit.colorHex ?? "#007AFF")
        let bounds = chartTimeBounds
        let noDataSegments = progressNoDataSegments

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress Chart")
                    .font(.headline)
                Spacer()
            }

            Chart {
                ForEach(progressDisplayPoints) { item in
                    // Subtle fill under the line
                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value(chartData.label, item.value)
                    )
                    .foregroundStyle(chartColor.opacity(0.12))

                    // Line on top
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value(chartData.label, item.value)
                    )
                    .foregroundStyle(chartColor)

                    // Less prominent points
                    PointMark(
                        x: .value("Date", item.date),
                        y: .value(chartData.label, item.value)
                    )
                    .symbolSize(20)
                    .foregroundStyle(chartColor.opacity(0.6))
                }
            }
            .frame(height: 200)
            .chartXScale(domain: bounds.lowerBound...bounds.upperBound)
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                    AxisGridLine()
                }
            }
            .chartYAxisLabel(chartData.label, position: .leading)
            .chartBackground { proxy in
                GeometryReader { geo in
                    ForEach(noDataSegments) { segment in
                        if let startX = proxy.position(forX: segment.start),
                           let endX = proxy.position(forX: segment.end) {
                            let minX = min(startX, endX)
                            let width = abs(endX - startX)
                            if width > 0 {
                                let rect = CGRect(x: minX, y: 0, width: width, height: geo.size.height)
                                Path { path in
                                    path.addRect(rect)
                                }
                                .fill(Color.gray.opacity(0.12))

                                Path { path in
                                    path.addRect(rect)
                                }
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                                .foregroundColor(Color.gray.opacity(0.4))

                                Text("No data")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .position(x: rect.midX, y: 16)
                            }
                        }
                    }
                }
            }

        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var timePeriodPickerView: some View {
        Picker("Time Period", selection: $selectedTimePeriod) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var reflectionsChartSection: some View {
        Group {
            if #available(iOS 16.0, *) {
                reflectionsChartModern
            }
        }
    }

    private var reflectionsLogSection: some View {
        Group {
            if journalEntries.isEmpty {
                reflectionsEmptyState
            } else {
                reflectionsLogContent
            }
        }
    }

    private var journalEntries: [HabitCompletion] {
        completions.compactMap { entry in
            guard let date = entry.completedDate else { return nil }
            if let start = timePeriodStartDate, date < start { return nil }
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
        let calendar = Calendar.current
        var dailyTotals: [Date: (total: Double, count: Int)] = [:]

        for entry in journalEntries {
            guard entry.moodScore > 0, let completed = entry.completedDate else { continue }
            let dayStart = calendar.startOfDay(for: completed)
            let clampedScore = Double(max(1, min(5, Int(entry.moodScore))))
            let running = dailyTotals[dayStart] ?? (0, 0)
            dailyTotals[dayStart] = (running.total + clampedScore, running.count + 1)
        }

        return dailyTotals.map { element in
            let (dayStart, aggregate) = element
            let rawAverage = aggregate.total / Double(aggregate.count)
            let average = min(5, max(1, rawAverage))
            let moodLevel = max(1, min(5, Int(average.rounded())))
            let displayDate = calendar.date(byAdding: .hour, value: 12, to: dayStart) ?? dayStart
            return MoodChartDataPoint(date: displayDate, averageMood: average, moodLevel: moodLevel)
        }
        .sorted { $0.date < $1.date }
    }

    private var moodTrendSegmentPoints: [MoodTrendSegmentPoint] {
        let points = moodDataPoints
        guard points.count > 1 else {
            return points.map {
                MoodTrendSegmentPoint(
                    segmentID: UUID(),
                    date: $0.date,
                    mood: $0.chartValue,
                    color: $0.color
                )
            }
        }

        var segments: [MoodTrendSegmentPoint] = []

        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            let startValue = start.chartValue
            let endValue = end.chartValue
            let interval = end.date.timeIntervalSince(start.date)
            let direction = endValue >= startValue ? 1 : -1
            let boundaries = moodBoundaries(from: start.moodLevel, to: end.moodLevel)

            var currentDate = start.date
            var currentValue = startValue
            var currentMood = start.moodLevel

            for boundary in boundaries {
                let boundaryValue = Double(boundary)
                let ratio: Double
                if endValue == startValue {
                    ratio = 0.0
                } else {
                    ratio = (boundaryValue - startValue) / (endValue - startValue)
                }

                let boundaryDate: Date
                if interval > 0 {
                    boundaryDate = start.date.addingTimeInterval(interval * ratio)
                } else {
                    boundaryDate = currentDate.addingTimeInterval(0.01)
                }

                let segmentID = UUID()
                let color = MoodPalette.color(for: currentMood)

                segments.append(MoodTrendSegmentPoint(segmentID: segmentID, date: currentDate, mood: currentValue, color: color))
                segments.append(MoodTrendSegmentPoint(segmentID: segmentID, date: boundaryDate, mood: boundaryValue, color: color))

                currentDate = boundaryDate
                currentValue = boundaryValue
                currentMood = max(1, min(5, currentMood + direction))
            }

            let finalSegmentID = UUID()
            let finalColor = MoodPalette.color(for: currentMood)
            segments.append(MoodTrendSegmentPoint(segmentID: finalSegmentID, date: currentDate, mood: currentValue, color: finalColor))
            segments.append(MoodTrendSegmentPoint(segmentID: finalSegmentID, date: end.date, mood: endValue, color: finalColor))
        }

        return segments
    }

    private func moodBoundaries(from startMood: Int, to endMood: Int) -> [Int] {
        if startMood == endMood { return [] }
        if startMood < endMood {
            return Array((startMood + 1)...endMood)
        } else {
            return Array((endMood + 1)...startMood).reversed()
        }
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

    private var reflectionsEmptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reflection Log")
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

    private var reflectionsLogContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Reflection Log")
                    .font(.headline)
                Spacer()
            }
            journalEntriesList
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @available(iOS 16.0, *)
    private var reflectionsChartModern: some View {
        let bounds = chartTimeBounds
        let noDataSegments = moodNoDataSegments

        return VStack(alignment: .leading, spacing: 32) {
            HStack {
                Text("Mood Chart")
                    .font(.headline)
                Spacer()
            }
            
            Chart {
                ForEach(moodTrendSegmentPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Mood", point.mood),
                        series: .value("Segment", point.segmentID.uuidString)
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(point.color)
                }

                ForEach(moodDataPoints) { point in
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Mood", point.chartValue)
                    )
                    .symbolSize(40)
                    .foregroundStyle(point.color)
                }
            }
            .chartYScale(domain: 0.5...5.5)
            .chartXScale(domain: bounds.lowerBound...bounds.upperBound)
            .chartYAxis {
                AxisMarks(position: .leading, values: Array(1...6)) { value in
                    AxisGridLine()
                    AxisValueLabel(centered: true) {
                        if let moodScore = value.as(Int.self) {
                            Circle()
                                .fill(MoodPalette.color(for: moodScore))
                                .frame(width: 12, height: 12)
                                .accessibilityLabel(Text(MoodPalette.label(for: moodScore)))
                        }
                    }
                    .offset(x: -8)
                }
            }
            .chartLegend(.hidden)
            .chartBackground { proxy in
                GeometryReader { geo in
                    ForEach(noDataSegments) { segment in
                        if let startX = proxy.position(forX: segment.start),
                           let endX = proxy.position(forX: segment.end) {
                            let minX = min(startX, endX)
                            let width = abs(endX - startX)
                            if width > 0 {
                                let rect = CGRect(x: minX, y: 0, width: width, height: geo.size.height)
                                Path { path in
                                    path.addRect(rect)
                                }
                                .fill(Color.gray.opacity(0.12))

                                Path { path in
                                    path.addRect(rect)
                                }
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                                .foregroundColor(Color.gray.opacity(0.4))

                                Text("No data")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .position(x: rect.midX, y: 16)
                            }
                        }
                    }
                }
            }
            .frame(height: 160)
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
    let averageMood: Double
    let moodLevel: Int

    var chartValue: Double { averageMood + 0.5 }
    var color: Color { MoodPalette.color(for: moodLevel) }
}

private struct MoodTrendSegmentPoint: Identifiable {
    let id = UUID()
    let segmentID: UUID
    let date: Date
    let mood: Double
    let color: Color
}

private struct NoDataSegment: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
}

    private var metricTotalThisWeek: Double {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today

        let weekCompletions = completions.filter { completion in
            guard let date = completion.completedDate else { return false }
            guard date >= weekStart else { return false }
            return !completion.isJournalOnly
        }

        return metricTotal(for: Array(weekCompletions))
    }

    private func metricTotal(for completions: [HabitCompletion]) -> Double {
        completions.reduce(0) { running, completion in
            if completion.metricAmount > 0 {
                return running + completion.metricAmount
            }
            if completion.isJournalOnly {
                return running
            }
            return running + habit.metricValue
        }
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

    private func getCompletions(for date: Date) -> [HabitCompletion] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        return completions.filter { completion in
            guard let completedDate = completion.completedDate else { return false }
            return completedDate >= dayStart && completedDate < dayEnd
        }
    }

    // 0 = none, 1 = partial, 2 = met
    private func getTargetStatusValue(for date: Date) -> Int {
        // Only color scheduled days
        if !habit.isScheduledForDate(date) { return 0 }
        let dayCompletions = getCompletions(for: date)
        if isTargetMet(on: date, with: dayCompletions) { return 2 }

        if habit.isTimerHabit {
            let minutes = dayCompletions.reduce(0.0) { $0 + $1.timerDuration }
            return minutes > 0 ? 1 : 0
        } else if habit.isRoutineHabit {
            let steps = dayCompletions.reduce(into: Set<Int>()) { acc, completion in
                if let string = completion.completedSteps, !string.isEmpty {
                    string.split(separator: ",").compactMap { Int($0) }.forEach { acc.insert($0) }
                }
            }
            return steps.count > 0 ? 1 : 0
        } else {
            return dayCompletions.count > 0 ? 1 : 0
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
        habit.habitDescription = "Daily mindfulness and reflection practice."

        // Seed recent journal entries with varying moods
        let calendar = Calendar.current
        let notes = [
            "Felt focused and calm after the session.",
            "A bit distracted today, but still showed up.",
            "Great energy! Wrapped up tasks quickly.",
            "Struggled to get started, but finished strong.",
            "Short session, yet helpful for clarity.",
            "Adding some more here",
            "Testing, Testing, Testing",
            "Please work properly for the love of god",
            "Why does the view still look like shit, who knows",
            "Testing the view with lots of entries"
        ]
        for offset in 0..<notes.count {
            let completion = HabitCompletion(context: context)
            completion.id = UUID()
            completion.completedDate = calendar.date(byAdding: .day, value: -offset, to: Date())
            completion.habit = habit
            completion.moodScore = Int16(Int.random(in: 1...5))
            completion.notes = notes[offset]
            completion.metricAmount = habit.metricValue
        }

        return HabitDetailView(habit: habit)
            .environment(\.managedObjectContext, context)
    }
}
