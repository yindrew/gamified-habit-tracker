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
                } else {
                    let completions1 = habit1.completions?.filtered(using: NSPredicate(format: "completedDate >= %@ AND completedDate < %@", today as NSDate, tomorrow as NSDate)).count ?? 0
                    let target1 = habit1.isScheduledToday ? habit1.targetFrequency : 0
                    isCompleted1 = completions1 >= target1
                }
                
                if habit2.isRoutineHabit {
                    isCompleted2 = habit2.updatedGoalMetToday
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
                                
                                HabitRowView(habit: habit, colorScheme: colorScheme)
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

struct HabitRowView: View {
    @ObservedObject var habit: Habit
    let colorScheme: String
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingCompletionAnimation = false
    @State private var isHolding = false
    @State private var holdProgress: Double = 0.0
    @State private var holdTimer: Timer?
    @State private var isInCooldown = false
    @State private var isRoutineExpanded = false
    
    private var isCompletedToday: Bool {
        guard let lastCompleted = habit.lastCompletedDate else { return false }
        return Calendar.current.isDateInToday(lastCompleted)
    }
    
    private var completionsToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let todayCompletions = habit.completions?.filtered(using: NSPredicate(format: "completedDate >= %@ AND completedDate < %@", today as NSDate, tomorrow as NSDate))
        return todayCompletions?.count ?? 0
    }
    
    private var progressPercentage: Double {
        if habit.isRoutineHabit {
            return habit.updatedRoutineProgressPercentage
        } else if habit.isScheduledToday {
            return habit.progressPercentage
        } else {
            return completionsToday > 0 ? 1.0 : 0.0
        }
    }
    
    private var isCompletedForDisplay: Bool {
        if habit.isRoutineHabit {
            return habit.updatedGoalMetToday
        } else if habit.isScheduledToday {
            // If scheduled today, check if goal is met
            return habit.goalMetToday
        } else {
            // If not scheduled today, only show as completed if actually attempted
            return completionsToday > 0
        }
    }
    
    private var buttonIcon: String {
        if habit.canUseCopingPlanToday {
            return "heart.fill"
        } else if isCompletedForDisplay {
            return "checkmark"
        } else {
            return "plus"
        }
    }
    
    private var buttonBackgroundColor: Color {
        if habit.canUseCopingPlanToday {
            return Color.pink.opacity(isHolding ? 0.3 : 0.1)
        } else if isCompletedForDisplay {
            return Color(hex: habit.colorHex ?? "#007AFF")
        } else {
            return Color(hex: habit.colorHex ?? "#007AFF").opacity(isHolding ? 0.3 : 0.1)
        }
    }
    
    private var buttonIconColor: Color {
        if habit.canUseCopingPlanToday {
            return .pink
        } else if isCompletedForDisplay {
            return .white
        } else {
            return Color(hex: habit.colorHex ?? "#007AFF")
        }
    }
    
    private var routineStepsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Progress bar with toggle button
            let progress = habit.routineProgress
            HStack(spacing: 8) {
                ProgressView(value: habit.updatedRoutineProgressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: habit.colorHex ?? "#007AFF")))
                    .frame(height: 4)
                
                Text("\(progress.completed)/\(progress.total) steps")
                    .font(.caption2)
                    .foregroundColor(habit.updatedGoalMetToday ? Color(hex: habit.colorHex ?? "#007AFF") : .secondary)
                    .fontWeight(habit.updatedGoalMetToday ? .bold : .medium)
                
                Spacer()
                
                // Toggle button to expand/collapse steps - bigger when collapsed
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isRoutineExpanded.toggle()
                    }
                }) {
                    if isRoutineExpanded {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        // Bigger toggle button when collapsed, similar to regular habit buttons
                        ZStack {
                            Circle()
                                .fill(Color(hex: habit.colorHex ?? "#007AFF").opacity(0.1))
                                .frame(width: 30, height: 30)
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Individual steps with details and hold rings (conditionally shown)
            if isRoutineExpanded {
                let steps = habit.routineStepsArray
                let completedSteps = habit.completedStepsToday
                
                if !steps.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            RoutineStepView(
                                step: step,
                                index: index,
                                isCompleted: completedSteps.contains(index),
                                habitColor: Color(hex: habit.colorHex ?? "#007AFF"),
                                onComplete: { toggleStep(at: index) }
                            )
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 15) {
            // Habit Icon
            ZStack {
                Circle()
                    .fill(Color(hex: habit.colorHex ?? "#007AFF").opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: habit.icon ?? "star")
                    .font(.title2)
                    .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(habit.name ?? "Unnamed Habit")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Streak indicator
                    if habit.currentStreak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("\(habit.currentStreak)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                
                // Progress bar or routine steps
                if habit.isRoutineHabit {
                    routineStepsView
                } else {
                    HStack(spacing: 8) {
                        ProgressView(value: progressPercentage)
                            .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: habit.colorHex ?? "#007AFF")))
                            .frame(height: 4)
                        
                        Text(habit.isScheduledToday ? habit.currentProgressString : "\(completionsToday) \(habit.metricUnit ?? "times")")
                            .font(.caption2)
                            .foregroundColor(isCompletedForDisplay ? Color(hex: habit.colorHex ?? "#007AFF") : .secondary)
                            .fontWeight(isCompletedForDisplay ? .bold : .medium)
                    }
                }
            }
            
            // Action buttons (only show for non-routine habits)
            if !habit.isRoutineHabit {
                HStack(spacing: 8) {
                    // Complete button with press-and-hold ring animation (only if scheduled today or daily)
                    ZStack {
                    // Background ring that fills up during hold
                    Circle()
                        .stroke(Color(hex: habit.colorHex ?? "#007AFF").opacity(0.2), lineWidth: 3)
                        .frame(width: 36, height: 36)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: holdProgress)
                        .stroke(
                            Color(hex: habit.colorHex ?? "#007AFF").opacity(0.6),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: holdProgress)
                    
                    // Main button
                    Circle()
                        .fill(buttonBackgroundColor)
                        .frame(width: 30, height: 30)
                        .scaleEffect(isHolding ? 0.95 : (showingCompletionAnimation ? 1.2 : 1.0))
                        .opacity(isInCooldown ? 0.5 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHolding)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showingCompletionAnimation)
                        .animation(.easeInOut(duration: 0.2), value: isInCooldown)
                    
                    Image(systemName: buttonIcon)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(buttonIconColor)
                        .scaleEffect(isHolding ? 0.9 : 1.0)
                        .opacity(isInCooldown ? 0.5 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHolding)
                        .animation(.easeInOut(duration: 0.2), value: isInCooldown)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isHolding && !isInCooldown {
                                startHolding()
                            }
                        }
                        .onEnded { _ in
                            endHolding()
                        }
                )

                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCompletedForDisplay ? Color(hex: habit.colorHex ?? "#007AFF").opacity(colorScheme == "light" ? 0.1 : 0.2) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.3), value: isCompletedForDisplay)
    }
    
    private func startHolding() {
        guard !isHolding && !isInCooldown else { return }
        
        isHolding = true
        holdProgress = 0.0
        
        // Light haptic feedback on start
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Start progress timer (1.5 second hold duration)
        let totalDuration: Double = 0.75
        let updateInterval: Double = 0.05
        let progressIncrement = updateInterval / totalDuration
        
        holdTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            holdProgress += progressIncrement
            
            if holdProgress >= 1.0 {
                timer.invalidate()
                completeHabit()
                endHolding(completed: true)
                startCooldown()
            }
        }
    }
    
    private func endHolding(completed: Bool = false) {
        holdTimer?.invalidate()
        holdTimer = nil
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isHolding = false
            if !completed {
                holdProgress = 0.0
            }
        }
        
        // Reset progress after animation if not completed
        if !completed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                holdProgress = 0.0
            }
        }
    }
    
    private func startCooldown() {
        isInCooldown = true
        
        // Reset progress after completion animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            holdProgress = 0.0
        }
        
        // End cooldown after 0.2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isInCooldown = false
        }
    }
    
    private func completeHabit() {
        // Check if this is a coping plan completion
        if habit.canUseCopingPlanToday {
            completeCopingPlan()
            return
        }
        
        // Strong haptic feedback on completion
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring()) {
            showingCompletionAnimation = true
            
            // Create completion record
            let completion = HabitCompletion(context: viewContext)
            completion.id = UUID()
            completion.completedDate = Date()
            completion.habit = habit
            
            // Update habit statistics
            habit.totalCompletions += 1
            habit.lastCompletedDate = Date()
            
            // Update streak
            updateStreak()
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
            
            // Reset animation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingCompletionAnimation = false
                holdProgress = 0.0
            }
        }
    }
    
    private func completeCopingPlan() {
        // Medium haptic feedback for coping plan
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring()) {
            showingCompletionAnimation = true
            
            // Complete the coping plan
            habit.completeCopingPlan()
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
            
            // Reset animation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingCompletionAnimation = false
                holdProgress = 0.0
            }
        }
    }
    
    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        guard let lastCompleted = habit.lastCompletedDate else {
            habit.currentStreak = 1
            habit.longestStreak = max(habit.longestStreak, 1)
            return
        }
        
        let lastCompletedDay = calendar.startOfDay(for: lastCompleted)
        let daysBetween = calendar.dateComponents([.day], from: lastCompletedDay, to: today).day ?? 0
        
        if daysBetween == 0 {
            // Completed today already, streak continues
            return
        } else if daysBetween == 1 {
            // Completed yesterday, increment streak
            habit.currentStreak += 1
        } else {
            // Gap in completions, reset streak
            habit.currentStreak = 1
        }
        
        habit.longestStreak = max(habit.longestStreak, habit.currentStreak)
    }
    
    private func toggleStep(at index: Int) {
        guard habit.isRoutineHabit else { return }
        
        // Light haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.3)) {
            // Create completion record for this step
            let completion = HabitCompletion(context: viewContext)
            completion.id = UUID()
            completion.completedDate = Date()
            completion.habit = habit
            completion.completedSteps = "\(index)"
            
            // Only update habit-level completion if ALL steps are now completed
            let wasFullyCompleted = habit.updatedGoalMetToday
            
            // Save the step completion first
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
            
            // Check if this step completion made the entire routine complete
            let isNowFullyCompleted = habit.updatedGoalMetToday
            
            // Only update habit statistics when the entire routine is completed for the first time today
            if !wasFullyCompleted && isNowFullyCompleted {
                habit.totalCompletions += 1
                habit.lastCompletedDate = Date()
                updateStreak()
                
                // Save again with habit-level updates
                do {
                    try viewContext.save()
                } catch {
                    let nsError = error as NSError
                    fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                }
            }
        }
    }
}

struct RoutineStepView: View {
    let step: String
    let index: Int
    let isCompleted: Bool
    let habitColor: Color
    let onComplete: () -> Void
    
    @State private var isHolding = false
    @State private var holdProgress: Double = 0.0
    @State private var holdTimer: Timer?
    @State private var isInCooldown = false
    @State private var showingCompletionAnimation = false
    
    private var buttonIcon: String {
        return isCompleted ? "checkmark" : "plus"
    }
    
    private var buttonBackgroundColor: Color {
        if isCompleted {
            return habitColor
        } else {
            return habitColor.opacity(isHolding ? 0.3 : 0.1)
        }
    }
    
    private var buttonIconColor: Color {
        return isCompleted ? .white : habitColor
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Step number
            Text("\(index + 1).")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)
            
            // Step description
            Text(step)
                .font(.caption2)
                .foregroundColor(isCompleted ? habitColor : .primary)
                .strikethrough(isCompleted)
                .lineLimit(1)
            
            Spacer()
            
            // Press-and-hold completion ring
            ZStack {
                // Background ring that fills up during hold
                Circle()
                    .stroke(habitColor.opacity(0.2), lineWidth: 2)
                    .frame(width: 28, height: 28)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(
                        habitColor.opacity(0.6),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: holdProgress)
                
                // Main button
                Circle()
                    .fill(buttonBackgroundColor)
                    .frame(width: 24, height: 24)
                    .scaleEffect(isHolding ? 0.95 : (showingCompletionAnimation ? 1.2 : 1.0))
                    .opacity(isInCooldown ? 0.5 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHolding)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showingCompletionAnimation)
                    .animation(.easeInOut(duration: 0.2), value: isInCooldown)
                
                Image(systemName: buttonIcon)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(buttonIconColor)
                    .scaleEffect(isHolding ? 0.9 : 1.0)
                    .opacity(isInCooldown ? 0.5 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHolding)
                    .animation(.easeInOut(duration: 0.2), value: isInCooldown)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isHolding && !isInCooldown && !isCompleted {
                            startHolding()
                        }
                    }
                    .onEnded { _ in
                        endHolding()
                    }
            )
        }
    }
    
    private func startHolding() {
        guard !isHolding && !isInCooldown && !isCompleted else { return }
        
        isHolding = true
        holdProgress = 0.0
        
        // Light haptic feedback on start
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Start progress timer (0.75 second hold duration)
        let totalDuration: Double = 0.75
        let updateInterval: Double = 0.05
        let progressIncrement = updateInterval / totalDuration
        
        holdTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            holdProgress += progressIncrement
            
            if holdProgress >= 1.0 {
                timer.invalidate()
                completeStep()
                endHolding(completed: true)
                startCooldown()
            }
        }
    }
    
    private func endHolding(completed: Bool = false) {
        holdTimer?.invalidate()
        holdTimer = nil
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isHolding = false
            if !completed {
                holdProgress = 0.0
            }
        }
        
        // Reset progress after animation if not completed
        if !completed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                holdProgress = 0.0
            }
        }
    }
    
    private func startCooldown() {
        isInCooldown = true
        
        // Reset progress after completion animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            holdProgress = 0.0
        }
        
        // End cooldown after 0.8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isInCooldown = false
        }
    }
    
    private func completeStep() {
        // Medium haptic feedback on completion
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring()) {
            showingCompletionAnimation = true
            
            // Call the completion handler
            onComplete()
            
            // Reset animation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingCompletionAnimation = false
                holdProgress = 0.0
            }
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
