//
//  ContentView.swift
//  gamified-habit-tracker
//
//  Created by Andrew Yin on 9/5/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAddHabit = false
    @State private var showCelebrationToast = false
    @State private var lastCelebrationDate: Date?
    @State private var showOnlyTodaysHabits = false
    @AppStorage("colorScheme") private var colorScheme: String = "light"
    @State private var activeTimerHabit: Habit?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Habit.createdDate, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default)
    private var habits: FetchedResults<Habit>
    
    private var filteredHabits: [Habit] {
        if showOnlyTodaysHabits {
            return habits.filter { $0.isScheduledToday }
        } else {
            return Array(habits)
        }
    }
    
    private var sortedHabits: [Habit] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return filteredHabits.sorted { habit1, habit2 in
            // Check if habits are scheduled for today
            let isScheduled1 = habit1.isScheduledToday
            let isScheduled2 = habit2.isScheduledToday
            
            // Prioritize scheduled habits
            if isScheduled1 != isScheduled2 {
                return isScheduled1 && !isScheduled2
            }
            
            // For scheduled habits, check completion status
            if isScheduled1 && isScheduled2 {
                // Use proper completion logic for routine vs frequency habits
                let isCompleted1: Bool
                let isCompleted2: Bool
                
                if habit1.isRoutineHabit {
                    isCompleted1 = habit1.updatedGoalMetToday
                } else if habit1.isTimerHabit {
                    isCompleted1 = habit1.timerGoalMetToday
                } else {
                    let completions1 = habit1.completions?.filtered(using: NSPredicate(format: "completedDate >= %@ AND completedDate < %@", today as NSDate, tomorrow as NSDate)).count ?? 0
                    let target1 = habit1.isScheduledToday ? habit1.targetFrequency : 0
                    isCompleted1 = completions1 >= target1
                }
                
                if habit2.isRoutineHabit {
                    isCompleted2 = habit2.updatedGoalMetToday
                } else if habit2.isTimerHabit {
                    isCompleted2 = habit2.timerGoalMetToday
                } else {
                    let completions2 = habit2.completions?.filtered(using: NSPredicate(format: "completedDate >= %@ AND completedDate < %@", today as NSDate, tomorrow as NSDate)).count ?? 0
                    let target2 = habit2.isScheduledToday ? habit2.targetFrequency : 0
                    isCompleted2 = completions2 >= target2
                }
                
                // Incomplete scheduled habits first
                if isCompleted1 != isCompleted2 {
                    return !isCompleted1 && isCompleted2
                }
            }
            
            // Within same group, sort by creation date
            return habit1.createdDate ?? Date() < habit2.createdDate ?? Date()
        }
    }
    
    private var scheduledHabitsForToday: [Habit] {
        return habits.filter { $0.isScheduledToday }
    }
    
    private var completedHabitsForToday: [Habit] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return habits.filter { habit in
            let completions = habit.completions?.filtered(using: NSPredicate(format: "completedDate >= %@ AND completedDate < %@", today as NSDate, tomorrow as NSDate)).count ?? 0
            return completions > 0
        }
    }
    
    private var scheduledHabitsCompletedToday: [Habit] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return scheduledHabitsForToday.filter { habit in
            return habit.goalMetToday
        }
    }
    
    private var allHabitsCompletedToday: Bool {
        let scheduledCount = scheduledHabitsForToday.count
        let completedScheduledCount = scheduledHabitsCompletedToday.count
        return scheduledCount > 0 && scheduledCount == completedScheduledCount
    }
    
    private var currentColorScheme: ColorScheme? {
        switch colorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return .light 
        }
    }
    

    private var themeIcon: String {
        switch colorScheme {
        case "light": return "sun.max"
        case "dark": return "moon"
        default: return "sun.max"
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                if habits.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "target")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Habits Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Tap the + button to create your first habit and start building better routines!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(sortedHabits, id: \.self) { habit in
                            ZStack {
                                NavigationLink(destination: HabitDetailView(habit: habit)) {
                                    EmptyView()
                                }
                                .opacity(0)
                                
                                HabitRowView(
                                    habit: habit, 
                                    colorScheme: colorScheme,
                                    activeTimerHabit: $activeTimerHabit
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                
                // Celebration toast overlay
                if showCelebrationToast {
                    CelebrationToastView(
                        completedHabits: scheduledHabitsCompletedToday,
                        isPresented: $showCelebrationToast
                    )
                    .zIndex(1000)
                }
            }
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("Habits")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Filter toggle
                        HStack(spacing: 4) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    showOnlyTodaysHabits = false
                                }
                            }) {
                                Text("All")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(showOnlyTodaysHabits ? .secondary : .primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(showOnlyTodaysHabits ? Color.clear : Color.accentColor.opacity(0.1))
                                    )
                            }
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    showOnlyTodaysHabits = true
                                }
                            }) {
                                Text("Today")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(showOnlyTodaysHabits ? .primary : .secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(showOnlyTodaysHabits ? Color.accentColor.opacity(0.1) : Color.clear)
                                    )
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.1))
                        )
                        
                        // Theme toggle
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                toggleTheme()
                            }
                        }) {
                            Image(systemName: themeIcon)
                                .font(.title2)
                                .fontWeight(.medium)
                        }
                        
                        Button(action: {
                            showingAddHabit = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                HabitFormView(mode: .add)
            }
            .onChange(of: allHabitsCompletedToday) { oldValue, newValue in
                checkForCelebration()
            }
            .onAppear {
                checkForCelebration()
            }
            .preferredColorScheme(currentColorScheme)
        }
    }
    
    private func checkForCelebration() {
        guard allHabitsCompletedToday else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Check if we've already shown celebration today
        if let lastCelebration = lastCelebrationDate,
           calendar.isDate(lastCelebration, inSameDayAs: today) {
            return
        }
        
        // Show celebration and mark date
        lastCelebrationDate = today
        showCelebrationToast = true
    }
    
    private func toggleTheme() {
        switch colorScheme {
        case "light":
            colorScheme = "dark"
        case "dark":
            colorScheme = "light"
        default:
            colorScheme = "light"
        }
    }

}



private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
