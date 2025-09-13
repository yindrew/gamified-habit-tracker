//
//  HabitRowView.swift
//  gamified-habit-tracker
//
//  Created by Andrew Yin on 9/5/25.
//

import SwiftUI
import CoreData


struct HabitRowView: View {

    @ObservedObject var habit: Habit
    let colorScheme: String
    @Binding var activeTimerHabit: Habit?
    @Environment(\.managedObjectContext) private var viewContext

    // Animation for Button
    @State private var showingCompletionAnimation = false

    // Timer/UI states managed locally; core values live in the view model
    @State private var showFocusMode = false

    @StateObject private var viewModel: HabitRowViewModel

    init(habit: Habit, colorScheme: String, activeTimerHabit: Binding<Habit?>) {
        self._habit = ObservedObject(wrappedValue: habit)
        self.colorScheme = colorScheme
        self._activeTimerHabit = activeTimerHabit
        self._viewModel = StateObject(wrappedValue: HabitRowViewModel(habit: habit))
    }


    // Timer running state is tracked in the view model
    
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
                        viewModel.isRoutineExpanded.toggle()
                    }
                }) {
                    if viewModel.isRoutineExpanded {
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
            if viewModel.isRoutineExpanded {
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
                                onComplete: { viewModel.toggleStep(at: index) }
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
                        ProgressView(value: viewModel.progressPercentage)
                            .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: habit.colorHex ?? "#007AFF")))
                            .frame(height: 4)
                            .animation(.linear(duration: 0.25), value: viewModel.progressPercentage)

                        HStack(spacing: 6) {
                            Text(viewModel.progressText)
                                .font(.caption2)
                                .foregroundColor(viewModel.isCompletedForDisplay ? Color(hex: habit.colorHex ?? "#007AFF") : .secondary)
                                .fontWeight(viewModel.isCompletedForDisplay ? .bold : .medium)
                            if let extra = viewModel.overrunText {
                                Text(extra)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            // Action buttons (extracted component)
            HabitActionButtons(
                ringColor: Color(hex: habit.colorHex ?? "#007AFF"),
                showExpand: habit.isTimerHabit && viewModel.isTimerRunning,
                mainFillColor: viewModel.buttonBackgroundColor,
                mainIcon: viewModel.buttonIcon,
                mainIconColor: viewModel.buttonIconColor,
                onMainHoldCompleted: { handleMainHoldCompleted() },
                onExpandHoldCompleted: {
                    DispatchQueue.main.async {
                        showFocusMode = true
                    }
                }
            )
            
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(viewModel.isCompletedForDisplay ? Color(hex: habit.colorHex ?? "#007AFF").opacity(colorScheme == "light" ? 0.1 : 0.2) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.3), value: viewModel.isCompletedForDisplay)
        .onChange(of: viewModel.didAutoStopAtGoal) { _, didStop in
            if didStop, showFocusMode {
                // Close focus mode when the goal is reached automatically
                showFocusMode = false
                // Reset the flag after handling
                viewModel.didAutoStopAtGoal = false
            }
        }
        .onAppear {
            // Provide Core Data context to the view model
            viewModel.setContext(viewContext)
        }
        .onDisappear {
            // Clean up timer if this view disappears
            if viewModel.isTimerRunning { viewModel.pauseTimer(saveProgress: true); activeTimerHabit = nil }
        }
        // Full screen focus mode for timers
        .fullScreenCover(isPresented: $showFocusMode) {
            FocusModeView(
                habit: habit,
                isPresented: $showFocusMode,
                elapsedTime: Binding(
                    get: { viewModel.totalElapsedSecondsToday },
                    set: { _ in }
                ),
                isRunning: viewModel.isTimerRunning,
                onToggleTimer: {
                    if viewModel.isTimerRunning {
                        viewModel.pauseTimer(saveProgress: true)
                        activeTimerHabit = nil
                    } else {
                        // If already met goal, resume in overrun; else count toward goal.
                        let allowOverrun = habit.timerGoalMetToday || ((viewModel.totalElapsedSecondsToday / 60.0) >= habit.goalValue)
                        viewModel.startTimer(allowOverrun: allowOverrun)
                        activeTimerHabit = habit
                    }
                }
            )
        }
    }
    
    // Press-hold logic is encapsulated by PressHoldRingButton

    private func handleMainHoldCompleted() {
        if habit.canUseCopingPlanToday {
            withAnimation(.spring()) { showingCompletionAnimation = true }
            viewModel.completeCopingPlan()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showingCompletionAnimation = false }
            return
        }
        if habit.isTimerHabit {
            // If goal already met, holding the checkmark lets the user keep going beyond the goal.
            let allowOverrun = habit.timerGoalMetToday
            if viewModel.isTimerRunning {
                viewModel.pauseTimer(saveProgress: true)
                activeTimerHabit = nil
            } else {
                viewModel.startTimer(allowOverrun: allowOverrun)
                activeTimerHabit = habit
            }
            return
        }
        if habit.isRoutineHabit {
            let steps = habit.routineStepsArray
            guard !steps.isEmpty else { return }
            let completed = habit.completedStepsToday
            if let nextIndex = (0..<steps.count).first(where: { !completed.contains($0) }) {
                viewModel.toggleStep(at: nextIndex)
            }
            return
        }
        withAnimation(.spring()) { showingCompletionAnimation = true }
        viewModel.completeHabit()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showingCompletionAnimation = false }
    }
}
