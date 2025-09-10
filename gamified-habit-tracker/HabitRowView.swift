//
//  HabitRowView.swift
//  gamified-habit-tracker
//
//  Created by Andrew Yin on 9/5/25.
//

import SwiftUI
import CoreData


struct HabitRowView: View {

    @ObservedObject var habit: Habit // View Model
    let colorScheme: String
    @Binding var activeTimerHabit: Habit? // View Model?
    @Environment(\.managedObjectContext) private var viewContext

    // Animation for Button
    @State private var showingCompletionAnimation = false
    @State private var isRoutineExpanded = false // view model 
    
    // Timer states
    @State private var timerElapsedTime: TimeInterval = 0 //vm
    @State private var runningTimer: Timer? //vm
    @State private var timerStartTime: Date? //vm
    @State private var showFocusMode = false //vm
    // Expand ring interactions are encapsulated by HabitActionButtons/PressHoldRingButton
    
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
            return Color.pink.opacity(0.1)
        } else if isCompletedForDisplay {
            return Color(hex: habit.colorHex ?? "#007AFF")
        } else {
            return Color(hex: habit.colorHex ?? "#007AFF").opacity(0.1)
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
        HStack(alignment: .center, spacing: 15) {
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
            
            // Action buttons (extracted component)
            HabitActionButtons(
                ringColor: Color(hex: habit.colorHex ?? "#007AFF"),
                showExpand: habit.isTimerHabit && isTimerRunning,
                mainFillColor: buttonBackgroundColor,
                mainIcon: buttonIcon,
                mainIconColor: buttonIconColor,
                onMainHoldCompleted: { handleMainHoldCompleted() },
                onExpandHoldCompleted: { showFocusMode = true }
            )
            
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
    
    // Press-hold logic is encapsulated by PressHoldRingButton

    private func handleMainHoldCompleted() {
        if habit.canUseCopingPlanToday {
            completeCopingPlan()
            return
        }
        if habit.isTimerHabit {
            if !habit.timerGoalMetToday {
                if isTimerRunning { pauseInlineTimer() } else { startInlineTimer() }
            }
            return
        }
        if habit.isRoutineHabit {
            completeEarliestRoutineStep()
            return
        }
        completeHabit()
    }

    private func completeEarliestRoutineStep() {
        let steps = habit.routineStepsArray
        guard !steps.isEmpty else { return }
        let completed = habit.completedStepsToday
        if let nextIndex = (0..<steps.count).first(where: { !completed.contains($0) }) {
            toggleStep(at: nextIndex)
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

    // Expand hold interactions are handled by HabitActionButtons
    
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
