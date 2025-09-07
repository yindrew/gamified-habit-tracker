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
    
    private var completionData: [DailyCompletion] {
        let calendar = Calendar.current
        let today = Date()
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -29, to: today) else {
            return []
        }
        
        var dailyData: [Date: Int] = [:]
        
        // Initialize all days with 0
        for i in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dayStart = calendar.startOfDay(for: date)
                dailyData[dayStart] = 0
            }
        }
        
        // Count completions per day - safely handle nil dates
        for completion in completions {
            guard let completedDate = completion.completedDate,
                  completedDate >= thirtyDaysAgo else { continue }
            
            let dayStart = calendar.startOfDay(for: completedDate)
            dailyData[dayStart, default: 0] += 1
        }
        
        return dailyData.map { DailyCompletion(date: $0.key, count: $0.value) }
            .sorted { $0.date < $1.date }
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
                
                // Progress chart
                if #available(iOS 16.0, *) {
                    progressChartView
                }
                
                // Recent completions
                recentCompletionsView
                
                // Streak history
                if !streakData.isEmpty {
                    streakHistoryView
                }
            }
            .padding()
        }
        .navigationTitle(habit.name ?? "Habit Details")
        .navigationBarTitleDisplayMode(.large)
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
                
                HStack {
                    Text("Target: \(habit.targetFrequency) time\(habit.targetFrequency == 1 ? "" : "s") per day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if habit.currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(habit.currentStreak) day streak")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                    }
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
            StatCard(title: "Current Streak", value: "\(habit.currentStreak) days", color: .orange)
            StatCard(title: "Longest Streak", value: "\(habit.longestStreak) days", color: .green)
            StatCard(title: "This Week", value: "\(completionsThisWeek)", color: .purple)
        }
    }
    
    @available(iOS 16.0, *)
    private var progressChartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 30 Days")
                .font(.headline)
            
            Chart(completionData) { item in
                BarMark(
                    x: .value("Date", item.date),
                    y: .value("Completions", item.count)
                )
                .foregroundStyle(Color(hex: habit.colorHex ?? "#007AFF"))
                .opacity(item.count > 0 ? 1.0 : 0.3)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                    AxisGridLine()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var recentCompletionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Completions")
                .font(.headline)
            
            if completions.isEmpty {
                Text("No completions yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(Array(completions.prefix(10)), id: \.id) { completion in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
                        
                        Text(completion.completedDate ?? Date(), formatter: dateFormatter)
                            .font(.body)
                        
                        Spacer()
                        
                        Text(completion.completedDate ?? Date(), formatter: timeFormatter)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var streakHistoryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streak History")
                .font(.headline)
            
            ForEach(streakData.prefix(5), id: \.startDate) { streak in
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading) {
                        Text("\(streak.length) day streak")
                            .font(.body)
                            .fontWeight(.semibold)
                        
                        Text("\(streak.startDate, formatter: dateFormatter) - \(streak.endDate, formatter: dateFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
