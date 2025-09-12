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
                
                // Statistics cards
                statisticsCardsView
                
                // Calendar view
                calendarView
                
                // Progress chart
                if #available(iOS 16.0, *) {
                    progressChartView
                }
            
            }
            .padding()
        }
        // .navigationTitle(habit.name ?? "Habit Details")
        // .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit Habit") {
                        showingEditHabit = true
                    }
                    
                    Button("Delete Habit", role: .destructive) {
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
        // Non-intrusive tap-away keyboard dismiss overlay
        .background(KeyboardDismissOverlay())
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
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            StatCard(title: "Total Completions", value: "\(habit.totalCompletions)", color: Color(hex: habit.colorHex ?? "#007AFF"))
            StatCard(title: "Current Streak", value: "\(habit.currentStreak) days", color: Color(hex: habit.colorHex ?? "#007AFF"))
            StatCard(title: "Longest Streak", value: "\(habit.longestStreak) days", color: Color(hex: habit.colorHex ?? "#007AFF"))
            StatCard(title: "This Week", value: "\(completionsThisWeek)", color: Color(hex: habit.colorHex ?? "#007AFF"))
        }
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
                BarMark(
                    x: .value("Date", item.date),
                    y: .value("Value", item.value)
                )
                .foregroundStyle(Color(hex: habit.colorHex ?? "#007AFF"))
                .opacity(item.value > 0 ? 1.0 : 0.3)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: getXAxisValues()) { value in
                    AxisValueLabel(format: getXAxisFormat())
                    AxisGridLine()
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
                let completionCount = getCompletionCount(for: date)
                days.append(CalendarDay(date: date, isInCurrentMonth: true, completionCount: completionCount))
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
                .opacity(day.completionCount > 0 ? (day.isInCurrentMonth ? 1.0 : 0.3) : 0.0)
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
