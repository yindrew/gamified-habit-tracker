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

struct HabitRowView: View {
    @ObservedObject var habit: Habit
    let colorScheme: String
    @Binding var activeTimerHabit: Habit?
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingCompletionAnimation = false
    @State private var isHolding = false
    @State private var holdProgress: Double = 0.0
    @State private var holdTimer: Timer?
    @State private var isInCooldown = false
    @State private var isRoutineExpanded = false
    
    // Timer states
    @State private var timerElapsedTime: TimeInterval = 0
    @State private var runningTimer: Timer?
    @State private var timerStartTime: Date?
    @State private var showFocusMode = false
    // Expand hold states
    @State private var isHoldingExpand = false
    @State private var holdProgressExpand: Double = 0.0
    @State private var holdTimerExpand: Timer?
    @State private var isInCooldownExpand = false
    
    private var isTimerRunning: Bool {
        activeTimerHabit?.id == habit.id
    }
    
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
        } else if habit.isTimerHabit {
            let totalMinutes = habit.timerMinutesToday + (timerElapsedTime / 60.0)
            let goal = max(habit.goalValue, 0.000001)
            return min(totalMinutes / goal, 1.0)
        } else if habit.isScheduledToday {
            return habit.progressPercentage
        } else {
            return completionsToday > 0 ? 1.0 : 0.0
        }
    }
    
    private var isCompletedForDisplay: Bool {
        if habit.isRoutineHabit {
            return habit.updatedGoalMetToday
        } else if habit.isTimerHabit {
            return habit.timerGoalMetToday
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
        } else if habit.isTimerHabit {
            return timerButtonIcon
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
    
    private var progressText: String {
        if habit.isTimerHabit {
            return timerRemainingDisplay
        } else if habit.isScheduledToday {
            return habit.currentProgressString
        } else {
            return "\(completionsToday) \(habit.metricUnit ?? "times")"
        }
    }

    private var timerRemainingDisplay: String {
        // goalValue is in minutes (Double). Include live elapsed time.
        let completedSeconds = (habit.timerMinutesToday * 60.0) + timerElapsedTime
        let goalSeconds = max(habit.goalValue * 60.0, 0)
        let remaining = max(0, goalSeconds - completedSeconds)
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        if remaining >= 3600 {
            return String(format: "%dh %dm left", hours, minutes)
        } else if remaining >= 60 {
            return String(format: "%dm left", minutes)
        } else {
            return String(format: "%ds left", seconds)
        }
    }
    
    private var timerButtonIcon: String {
        if habit.timerGoalMetToday {
            return "checkmark"
        } else if isTimerRunning {
            return "pause.fill"
        } else {
            return "play.fill"
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
                        // Same size as collapsed button for consistency
                        ZStack {
                            Circle()
                                .fill(Color(hex: habit.colorHex ?? "#007AFF").opacity(0.1))
                                .frame(width: 30, height: 30)
                            
                            Image(systemName: "chevron.up")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
                        }
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
        HStack(alignment: .top, spacing: 15) {
            // Habit Icon
            ZStack {
                Circle()
                    .fill(Color(hex: habit.colorHex ?? "#007AFF").opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: habit.icon ?? "star")
                    .font(.title2)
                    .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
            }
            .padding(.top, 2) // Align with title baseline
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
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
                            .animation(.linear(duration: 0.25), value: progressPercentage)
                        
                        Text(progressText)
                            .font(.caption2)
                            .foregroundColor(isCompletedForDisplay ? Color(hex: habit.colorHex ?? "#007AFF") : .secondary)
                            .fontWeight(isCompletedForDisplay ? .bold : .medium)
                    }
                }
            }
            
            // Action button ring (show for all non-routine habits, including timers)
            if !habit.isRoutineHabit {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        // When timer is running, show an expand focus button to the LEFT of the play/pause ring
                        if habit.isTimerHabit && isTimerRunning {
                            ZStack {
                                Circle()
                                    .stroke(Color(hex: habit.colorHex ?? "#007AFF").opacity(0.2), lineWidth: 3)
                                    .frame(width: 36, height: 36)

                                Circle()
                                    .trim(from: 0, to: holdProgressExpand)
                                    .stroke(
                                        Color(hex: habit.colorHex ?? "#007AFF").opacity(0.6),
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                    )
                                    .frame(width: 36, height: 36)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear(duration: 0.1), value: holdProgressExpand)

                                Circle()
                                    .fill(Color(hex: habit.colorHex ?? "#007AFF").opacity(isHoldingExpand ? 0.3 : 0.1))
                                    .frame(width: 30, height: 30)
                                    .scaleEffect(isHoldingExpand ? 0.95 : 1.0)
                                    .opacity(isInCooldownExpand ? 0.5 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHoldingExpand)
                                    .animation(.easeInOut(duration: 0.2), value: isInCooldownExpand)

                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
                                    .scaleEffect(isHoldingExpand ? 0.9 : 1.0)
                                    .opacity(isInCooldownExpand ? 0.5 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHoldingExpand)
                                    .animation(.easeInOut(duration: 0.2), value: isInCooldownExpand)
                            }
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if !isHoldingExpand && !isInCooldownExpand {
                                            startHoldingExpand()
                                        }
                                    }
                                    .onEnded { _ in
                                        endHoldingExpand()
                                    }
                            )
                        }

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
                    Spacer()
                }
            }
            
            // Timer action button removed: timer now uses the main hold ring
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCompletedForDisplay ? Color(hex: habit.colorHex ?? "#007AFF").opacity(colorScheme == "light" ? 0.1 : 0.2) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.3), value: isCompletedForDisplay)
        .onDisappear {
            // Clean up timer if this view disappears
            if isTimerRunning {
                pauseInlineTimer()
            }
        }
        // Full screen focus mode for timers
        .fullScreenCover(isPresented: $showFocusMode) {
            FocusModeView(
                habit: habit,
                isPresented: $showFocusMode,
                elapsedTime: $timerElapsedTime,
                isRunning: isTimerRunning,
                onToggleTimer: {
                    if isTimerRunning { pauseInlineTimer() } else { startInlineTimer() }
                }
            )
        }
    }
    
    private func startHolding() {
        guard !isHolding && !isInCooldown else { return }
        
        isHolding = true
        holdProgress = 0.0
        
        // Light haptic feedback on start
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Hold duration
        let totalDuration: Double = 0.75
        let updateInterval: Double = 0.05
        let progressIncrement = updateInterval / totalDuration
        
        holdTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            holdProgress += progressIncrement
            
            if holdProgress >= 1.0 {
                timer.invalidate()
                // On hold complete, branch logic based on habit type
                if habit.canUseCopingPlanToday {
                    completeCopingPlan()
                    endHolding(completed: true)
                    startCooldown()
                } else if habit.isTimerHabit {
                    if !habit.timerGoalMetToday {
                        if isTimerRunning {
                            pauseInlineTimer()
                        } else {
                            startInlineTimer()
                        }
                    }
                    endHolding(completed: true)
                    startCooldown()
                } else {
                    completeHabit()
                    endHolding(completed: true)
                    startCooldown()
                }
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
    
    
    private func startInlineTimer() {
        // Medium haptic feedback for timer start
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
            activeTimerHabit = habit
        timerStartTime = Date()
        timerElapsedTime = 0
        
        runningTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            if let start = timerStartTime {
                timerElapsedTime = Date().timeIntervalSince(start)
                
                // Check if goal is completed
                let totalMinutesToday = habit.timerMinutesToday + (timerElapsedTime / 60.0)
                if totalMinutesToday >= habit.goalValue {
                    // Goal completed!
                    pauseInlineTimer()
                    saveInlineTimerProgress()
                }
            }
        }
    }
    
    private func pauseInlineTimer() {
        // Light haptic feedback for pause
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        runningTimer?.invalidate()
        runningTimer = nil
            activeTimerHabit = nil
        
        // Save progress when pausing
        if timerElapsedTime > 0 {
            saveInlineTimerProgress()
        }
    }

    // MARK: - Expand Hold helpers
    private func startHoldingExpand() {
        guard !isHoldingExpand && !isInCooldownExpand else { return }
        isHoldingExpand = true
        holdProgressExpand = 0.0

        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        let totalDuration: Double = 0.75
        let updateInterval: Double = 0.05
        let progressIncrement = updateInterval / totalDuration

        holdTimerExpand = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            holdProgressExpand += progressIncrement
            if holdProgressExpand >= 1.0 {
                timer.invalidate()
                endHoldingExpand(completed: true)
                startCooldownExpand()
                showFocusMode = true
            }
        }
    }

    private func endHoldingExpand(completed: Bool = false) {
        holdTimerExpand?.invalidate()
        holdTimerExpand = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isHoldingExpand = false
            if !completed { holdProgressExpand = 0.0 }
        }
        if !completed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { holdProgressExpand = 0.0 }
        }
    }

    private func startCooldownExpand() {
        isInCooldownExpand = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { holdProgressExpand = 0.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { isInCooldownExpand = false }
    }
    
    private func saveInlineTimerProgress() {
        guard timerElapsedTime > 0 else { return }
        
        let completion = HabitCompletion(context: viewContext)
        completion.id = UUID()
        completion.completedDate = Date()
        completion.habit = habit
        completion.timerDuration = timerElapsedTime / 60.0 // Convert to minutes
        
        // Update habit statistics if goal is reached for the first time today
        let totalMinutesToday = habit.timerMinutesToday + (timerElapsedTime / 60.0)
        if totalMinutesToday >= habit.goalValue && !habit.timerGoalMetToday {
            habit.totalCompletions += 1
            habit.lastCompletedDate = Date()
        }
        
        do {
            try viewContext.save()
            // Reset timer state
            timerElapsedTime = 0
            timerStartTime = nil
        } catch {
            print("Error saving timer completion: \(error)")
        }
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
