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

    @State private var activeAddSheet: AddHabitSheet?
    @State private var showCelebrationToast = false
    @State private var lastCelebrationDate: Date?
    @State private var activeTimerHabit: Habit?

    @AppStorage("colorScheme") private var colorSchemePreference: String = "system"
    @AppStorage("habitLayoutStyle") private var habitLayoutStyle: String = "wide"
    @AppStorage("showOnlyTodaysHabits") private var showOnlyTodaysHabits = false

    private enum AddHabitSheet: String, Identifiable {
        case standard
        case ethereal
        var id: String { rawValue }
    }

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
                let isCompleted1 = habit1.goalMetToday
                let isCompleted2 = habit2.goalMetToday

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
    
    private var scheduledHabitsCompletedToday: [Habit] {        
        return scheduledHabitsForToday.filter { habit in
            return habit.goalMetToday
        }
    }
    
    private var allHabitsCompletedToday: Bool {
        let scheduledCount = scheduledHabitsForToday.count
        let completedScheduledCount = scheduledHabitsCompletedToday.count
        return scheduledCount > 0 && scheduledCount == completedScheduledCount
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
    
    var body: some View {
        NavigationView {
            ZStack {
                content()

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
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: toggleFilter) {
                            Label(filterMenuTitle, systemImage: filterMenuIcon)
                        }
                        Button(action: toggleLayoutStyle) {
                            Label(layoutMenuTitle, systemImage: layoutMenuIcon)
                        }
                        Button(action: toggleTheme) {
                            Label(themeMenuTitle, systemImage: themeMenuIcon)
                        }
                        
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title2)
                            .fontWeight(.medium)
                    }
                    .accessibilityLabel(Text("View options"))
                }

                ToolbarItem(placement: .principal) { toolbarPrincipal }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            activeAddSheet = .standard
                        } label: {
                            Label("Add Recurring Habit", systemImage: "checkmark.circle")
                        }

                        Button {
                            activeAddSheet = .ethereal
                        } label: {
                            Label("Add One Time Task", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.medium)
                    }
                    .accessibilityLabel(Text("Add"))
                }
            }
            .sheet(item: $activeAddSheet) { sheet in
                switch sheet {
                case .standard:
                    HabitFormView(mode: .add)
                case .ethereal:
                    EtherealHabitQuickAddView()
                }
            }
            .onChange(of: allHabitsCompletedToday) { _, _ in checkForCelebration() }
            .onAppear { checkForCelebration() }
            .preferredColorScheme(currentColorScheme)
        }
    }
    
    @ViewBuilder
    private func content() -> some View {
        if habits.isEmpty {
            EmptyHabitsView()
        } else {
            HabitsListView(
                sortedHabits: sortedHabits,
                isWideView: isWideView,
                activeTimerHabit: $activeTimerHabit,
            )
        }
    }

    private var toolbarPrincipal: some View {
        Text("Trackr")
            .font(.largeTitle)
            .fontWeight(.bold)
    }

    private var isWideView: Bool {
        habitLayoutStyle == "wide"
    }

    private var filterMenuTitle: String {
        showOnlyTodaysHabits ? "Show All Habits" : "Show Today's Habits"
    }

    private var filterMenuIcon: String {
        showOnlyTodaysHabits ? "list.bullet" : "calendar.circle"
    }

    private var layoutMenuTitle: String {
        isWideView ? "Use Narrow Layout" : "Use Wide Layout"
    }

    private var layoutMenuIcon: String {
        isWideView ? "rectangle.compress.vertical" : "rectangle.expand.vertical"
    }

    private var currentColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var themeMenuTitle: String {
        switch colorSchemePreference {
        case "light": return "Use Dark Mode"
        case "dark": return "Use Light Mode"
        default: return "Use Dark Mode"
        }
    }

    private var themeMenuIcon: String {
        colorSchemePreference == "dark" ? "sun.max" : "moon"
    }

    private func toggleFilter() {
        withAnimation(.spring(response: 0.3)) {
            showOnlyTodaysHabits.toggle()
        }
    }

    private func toggleLayoutStyle() {
        withAnimation(.easeInOut(duration: 0.25)) {
            habitLayoutStyle = isWideView ? "narrow" : "wide"
        }
    }

    private func toggleTheme() {
        switch colorSchemePreference {
        case "light":
            colorSchemePreference = "dark"
        case "dark":
            colorSchemePreference = "light"
        default:
            colorSchemePreference = "dark"
        }
    }
    

}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

private struct EmptyHabitsView: View {
    var body: some View {
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
    }
}

private struct HabitsListView: View {
    let sortedHabits: [Habit]
    let isWideView: Bool
    @Binding var activeTimerHabit: Habit?

    var body: some View {
        List {
            ForEach(sortedHabits, id: \.objectID) { (habit: Habit) in
                HabitRowView(
                    habit: habit,
                    isWideView: isWideView,
                    activeTimerHabit: $activeTimerHabit,
                )
                .background(
                    NavigationLink(
                        destination: HabitDetailView(habit: habit)
                    ) {
                        EmptyView()
                    }
                    .opacity(0)
                )
                .listRowInsets(EdgeInsets(top: 4, leading: isWideView ? 12 : 0, bottom: 4, trailing: isWideView ? 12 : 0))
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(PlainListStyle())
        .padding(.top, isWideView ? -12 : -20)
        .contentMargins(.top, isWideView ? -8 : -12)
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
