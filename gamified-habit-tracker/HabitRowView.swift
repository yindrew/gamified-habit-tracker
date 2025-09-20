//
//  HabitRowView.swift
//  gamified-habit-tracker
//
//  Created by Andrew Yin on 9/5/25.
//

import SwiftUI
import CoreData
import UIKit


struct HabitRowView: View {

    @ObservedObject var habit: Habit
    let isWideView: Bool
    @Binding var activeTimerHabit: Habit?
    let onDelete: (Habit) -> Void
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

    // Animation for Button
    @State private var showingCompletionAnimation = false

    // Timer/UI states managed locally; core values live in the view model
    @State private var showFocusMode = false
    @State private var journalCompletion: HabitCompletion?
    @State private var hasShownJournalForCurrentCompletion = false
    @State private var showingCustomLogPrompt = false
    @State private var customLogValueText = ""
    @State private var customLogValidationMessage: String?
    @State private var showingEditHabit = false
    @State private var showingDeleteConfirmation = false

    @StateObject private var viewModel: HabitRowViewModel

    init(habit: Habit, isWideView: Bool = false, activeTimerHabit: Binding<Habit?>, onDelete: @escaping (Habit) -> Void = { _ in }) {
        self._habit = ObservedObject(wrappedValue: habit)
        self.isWideView = isWideView
        self._activeTimerHabit = activeTimerHabit
        self.onDelete = onDelete
        self._viewModel = StateObject(wrappedValue: HabitRowViewModel(habit: habit))
    }


    // Timer running state is tracked in the view model
    
    private var routineStepsView: some View {
        VStack(alignment: .leading, spacing: routineSpacing) {
            // Progress bar with toggle button
            let progress = habit.routineProgress
            HStack(spacing: 8) {
                ProgressView(value: habit.updatedRoutineProgressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: habit.colorHex ?? "#007AFF")))
                    .frame(height: 4)
                
                Text("\(progress.completed)/\(progress.total) steps")
                    .font(.caption2)
                    .foregroundColor(habit.routineGoalMetToday ? Color(hex: habit.colorHex ?? "#007AFF") : .secondary)
                    .fontWeight(habit.routineGoalMetToday ? .bold : .medium)
                
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
                                .frame(width: routineToggleSize, height: routineToggleSize)
                            
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
                                .frame(width: routineToggleSize, height: routineToggleSize)
                            
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
                    VStack(alignment: .leading, spacing: routineSpacing) {
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
        mainContentView
            .modifier(HabitRowModifiers(
                habit: habit,
                viewModel: viewModel,
                showFocusMode: $showFocusMode,
                journalCompletion: $journalCompletion,
                hasShownJournalForCurrentCompletion: $hasShownJournalForCurrentCompletion,
                showingCustomLogPrompt: $showingCustomLogPrompt,
                customLogValueText: $customLogValueText,
                customLogValidationMessage: $customLogValidationMessage,
                showingEditHabit: $showingEditHabit,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                activeTimerHabit: $activeTimerHabit,
                onDelete: onDelete,
                presentCustomLogPrompt: presentCustomLogPrompt,
                attemptCustomLogSave: attemptCustomLogSave,
                verticalPadding: verticalPadding,
                horizontalPadding: horizontalPadding
            ))
    }
    
    private var mainContentView: some View {

        HStack(alignment: rowAlignment, spacing: horizontalSpacing) {
            // Habit Icon
            iconView

            VStack(alignment: .leading, spacing: detailSpacing) {
                habitTitleView
                
                if isWideView, let description = habit.habitDescription, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if habit.isRoutineHabit {
                    routineStepsView
                } else {
                    progressView
                }

                if isWideView {
                    infoChipsView
                }
            }

            actionButtonsView
        }
        .padding(.top, topPadding)
        .contentShape(Rectangle())
    }
    
    private var habitTitleView: some View {
        HStack(alignment: .center) {
            Text(habit.name ?? "Unnamed Habit")
                .font(titleFont)
                .foregroundColor(.primary)

            Spacer()

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
    }
    
    private var progressView: some View {
        HStack(spacing: 8) {
            ProgressView(value: viewModel.progressPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: habit.colorHex ?? "#007AFF")))
                .frame(height: progressBarHeight)
                .animation(.linear(duration: 0.25), value: viewModel.progressPercentage)

            HStack(spacing: 6) {
                Text(viewModel.progressText)
                    .font(.caption2)
                    .foregroundColor(viewModel.isCompletedForDisplay ? Color(hex: habit.colorHex ?? "#007AFF") : .secondary)
                    .fontWeight(viewModel.isCompletedForDisplay ? .bold : .medium)
            }
        }
    }
    
    private var infoChipsView: some View {
        HStack(spacing: 12) {
            if let typeChip = typeChip {
                infoChip(icon: typeChip.icon, text: typeChip.text)
            }

            infoChip(icon: "calendar", text: scheduleChipText)
        }
    }
    
    // MARK: - Custom Log Helpers

    private func presentCustomLogPrompt() {
        guard !habit.isEtherealHabit else { return }
        customLogValidationMessage = nil
        customLogValueText = defaultCustomLogValue
        showingCustomLogPrompt = true
    }

    private var defaultCustomLogValue: String {
        if habit.isTimerHabit {
            return formattedValue(15, allowDecimals: true)
        }
        if habit.isRoutineHabit {
            return "1"
        }
        let base = habit.metricValue > 0 ? habit.metricValue : 1
        return formattedValue(base, allowDecimals: allowsDecimalInput)
    }

    private var customLogFieldLabel: String {
        if habit.isTimerHabit { return "Minutes" }
        if habit.isRoutineHabit { return "Steps" }
        return habit.metricUnit ?? "Amount"
    }

    private var customLogUnitLabel: String? {
        if habit.isTimerHabit { return "min" }
        if habit.isRoutineHabit { return nil }
        return habit.metricUnit
    }

    private var allowsDecimalInput: Bool {
        if habit.isTimerHabit { return true }
        if habit.isRoutineHabit { return false }
        return habit.metricValue.truncatingRemainder(dividingBy: 1) != 0
    }

    private func attemptCustomLogSave() {
        guard let value = parsedCustomLogValue() else {
            customLogValidationMessage = "Enter a value greater than zero."
            return
        }

        if habit.isRoutineHabit {
            let intValue = Int(value.rounded(.towardZero))
            guard intValue > 0 else {
                customLogValidationMessage = "Add at least one step."
                return
            }
            logCustomValue(amount: Double(intValue))
            showingCustomLogPrompt = false
            customLogValueText = ""
            return
        }

        logCustomValue(amount: value)
        showingCustomLogPrompt = false
        customLogValueText = ""
    }

    private func parsedCustomLogValue() -> Double? {
        let trimmed = customLogValueText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }

    private func formattedValue(_ value: Double, allowDecimals: Bool) -> String {
        if !allowDecimals || value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value.rounded(.towardZero)))
        }
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    // Press-hold logic is encapsulated by PressHoldRingButton

    private func logCustomValue(amount: Double) {
        let habitWasCompleted = viewModel.isCompletedForDisplay
        let value = amount
        guard value > 0 else { return }
        if habit.isEtherealHabit { return }

        if habit.isRoutineHabit {
            logRoutineSteps(count: Int(value.rounded(.towardZero)))
            hasShownJournalForCurrentCompletion = false
            return
        }

        let now = Date()

        if habit.isTimerHabit {
            let minutesBefore = habit.timerMinutesToday
            let completion = HabitCompletion(context: viewContext)
            completion.id = UUID()
            completion.completedDate = now
            completion.habit = habit
            completion.timerDuration = value

            let minutesAfter = minutesBefore + value
            if minutesBefore < habit.goalValue && minutesAfter >= habit.goalValue {
                habit.totalCompletions += 1
                habit.lastCompletedDate = now
                updateHabitStreakAfterCompletion()
            }
        } else {
            let metricPerCompletion = habit.metricValue > 0 ? habit.metricValue : 1
            let progressBefore = habit.currentProgress

            let completion = HabitCompletion(context: viewContext)
            completion.id = UUID()
            completion.completedDate = now
            completion.habit = habit
            completion.metricAmount = value

            let progressAfter = progressBefore + value
            let previousCompletionCount = Int32((progressBefore / metricPerCompletion).rounded(.down))
            let newCompletionCount = Int32((progressAfter / metricPerCompletion).rounded(.down))
            let completionDelta = max(0, newCompletionCount - previousCompletionCount)

            if completionDelta > 0 {
                habit.totalCompletions += completionDelta
                habit.lastCompletedDate = now
            }

            if progressBefore < habit.goalValue && progressAfter >= habit.goalValue {
                updateHabitStreakAfterCompletion()
            }
        }

        do {
            try viewContext.save()
            HabitWidgetExporter.shared.scheduleSync(using: viewContext)
            hasShownJournalForCurrentCompletion = false
            if !habitWasCompleted && shouldPromptForJournal() {
                _ = viewModel.prepareAdditionalReflection()
            }
        } catch {
            viewContext.rollback()
        }
    }

    private func logRoutineSteps(count: Int) {
        let stepsToMark = max(0, count)
        guard stepsToMark > 0 else { return }
        let steps = habit.routineStepsArray
        guard !steps.isEmpty else { return }

        var remaining = stepsToMark
        var completed = habit.completedStepsToday

        for index in 0..<steps.count where remaining > 0 {
            if !completed.contains(index) {
                viewModel.toggleStep(at: index)
                completed.insert(index)
                remaining -= 1
            }
        }
    }

    private func updateHabitStreakAfterCompletion() {
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
            return
        } else if daysBetween == 1 {
            habit.currentStreak += 1
        } else {
            habit.currentStreak = 1
        }

        habit.longestStreak = max(habit.longestStreak, habit.currentStreak)
    }

    private func shouldPromptForJournal() -> Bool {
        if habit.isTimerHabit { return habit.timerGoalMetToday }
        if habit.isRoutineHabit { return habit.routineGoalMetToday }
        return habit.goalMetToday
    }

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

private struct JournalEntrySheet: View {
    @ObservedObject var completion: HabitCompletion
    let onFinish: () -> Void

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var mood: Int
    @State private var notes: String

    init(completion: HabitCompletion, onFinish: @escaping () -> Void) {
        self.completion = completion
        self.onFinish = onFinish
        let existingMood = Int(completion.moodScore)
        _mood = State(initialValue: (1...5).contains(existingMood) ? existingMood : 3)
        _notes = State(initialValue: completion.notes ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Mood")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 16) {
                            ForEach(1...5, id: \.self) { value in
                                Circle()
                                    .fill(MoodPalette.color(for: value))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary.opacity(mood == value ? 0.9 : 0.3), lineWidth: mood == value ? 3 : 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: mood == value ? 3 : 0)
                                    .onTapGesture { mood = value }
                                    .accessibilityLabel(Text(MoodPalette.label(for: value)))
                            }
                        }
                        Text(MoodPalette.label(for: mood))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Journal")) {
                    TextField("How was the habit today...", text: $notes, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Reflect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { closeSheet(save: false) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { closeSheet(save: true) }
                }
            }
        }
    }

    private func closeSheet(save: Bool) {
        if save {
            completion.moodScore = Int16(mood)
            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            completion.notes = trimmed.isEmpty ? nil : trimmed
            do {
                try viewContext.save()
                HabitWidgetExporter.shared.scheduleSync(using: viewContext)
            } catch {
                #if DEBUG
                print("[JournalEntrySheet] Failed to save journal: \(error)")
                #endif
            }
        } else {
            if completion.isInserted {
                viewContext.delete(completion)
                do {
                    try viewContext.save()
                } catch {
                    viewContext.rollback()
                }
            } else {
                viewContext.refresh(completion, mergeChanges: false)
            }
        }
        dismiss()
        onFinish()
    }
}

private struct CustomLogPromptView: View {
    let fieldLabel: String
    let unitLabel: String?
    @Binding var valueText: String
    let validationMessage: String?
    let allowsDecimal: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Log Progress")
                    .font(.headline)
                Text("Log custom values toward your goal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    TextField(fieldLabel, text: $valueText)
                        .keyboardType(allowsDecimal ? .decimalPad : .numberPad)
                        .focused($isFieldFocused)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)

                    if let unit = unitLabel, !unit.isEmpty {
                        Text(unit)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                }

                if let validation = validationMessage {
                    Text(validation)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }

            HStack(spacing: 16) {
                Button("Cancel") { onCancel() }
                    .foregroundColor(.secondary)
                Spacer()
                Button("Save") { onSave() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: 420)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 20, y: 12)
    }
}


private extension HabitRowView {
    var iconSize: CGFloat { isWideView ? 60 : 50 }

    var iconFont: Font { isWideView ? .title : .title2 }

    var iconBackgroundOpacity: Double { isWideView ? 0.12 : 0.1 }

    var detailSpacing: CGFloat { isWideView ? 8 : 4 }

    var horizontalSpacing: CGFloat { isWideView ? 20 : 15 }

    var titleFont: Font { isWideView ? .title3 : .headline }

    var progressBarHeight: CGFloat { isWideView ? 6 : 4 }

    var topPadding: CGFloat {
        if habit.isRoutineHabit {
            return isWideView ? 10 : 6
        }
        return isWideView ? 4 : 0
    }

    var verticalPadding: CGFloat { isWideView ? 14 : 4 }

    var horizontalPadding: CGFloat { isWideView ? 16 : 12 }

    var routineSpacing: CGFloat { isWideView ? 8 : 6 }

    var routineToggleSize: CGFloat { isWideView ? 34 : 30 }

    var rowAlignment: VerticalAlignment { isWideView ? .center : .top }

    var scheduleChipText: String {
        if habit.isEtherealHabit {
            return "Once"
        }
        switch habit.schedule {
        case .weekly:
            return "Custom Weekly"
        case .monthly:
            return "Custom Monthly"
        default:
            return habit.schedule.displayName
        }
    }

    var typeChip: (icon: String, text: String)? {
        if habit.isEtherealHabit {
            return ("sparkles", "Task")
        }
        if habit.isRoutineHabit {
            return ("checklist", "Routine")
        }
        if habit.isTimerHabit {
            return ("timer", "Timer")
        }
        return ("number", "Frequency")
    }

    var iconView: some View {
        let base = ZStack {
            Circle()
                .fill(Color(hex: habit.colorHex ?? "#007AFF").opacity(iconBackgroundOpacity))
                .frame(width: iconSize, height: iconSize)

            Image(systemName: habit.icon ?? "star")
                .font(iconFont)
                .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
        }
        .frame(width: iconSize, height: iconSize)

        return Group {
            if isWideView {
                base
                    .frame(minHeight: iconSize)
                    .frame(maxHeight: .infinity, alignment: .center)
            } else {
                base
            }
        }
    }

    var actionButtonsView: some View {
        let buttons = HabitActionButtons(
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
        .scaleEffect(isWideView ? 1.3 : 1.08)
        .frame(minHeight: iconSize)

        return Group {
            if isWideView {
                buttons.frame(maxHeight: .infinity, alignment: .center)
            } else {
                buttons
            }
        }
    }

    @ViewBuilder
    func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .fontWeight(.semibold)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }
}

// MARK: - View Modifiers

private struct HabitRowModifiers: ViewModifier {
    @ObservedObject var habit: Habit
    @ObservedObject var viewModel: HabitRowViewModel
    @Binding var showFocusMode: Bool
    @Binding var journalCompletion: HabitCompletion?
    @Binding var hasShownJournalForCurrentCompletion: Bool
    @Binding var showingCustomLogPrompt: Bool
    @Binding var customLogValueText: String
    @Binding var customLogValidationMessage: String?
    @Binding var showingEditHabit: Bool
    @Binding var showingDeleteConfirmation: Bool
    @Binding var activeTimerHabit: Habit?
    let onDelete: (Habit) -> Void
    let presentCustomLogPrompt: () -> Void
    let attemptCustomLogSave: () -> Void
    let verticalPadding: CGFloat
    let horizontalPadding: CGFloat
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                trailingSwipeActions
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                leadingSwipeActions
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(backgroundView)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isCompletedForDisplay)
            .onChange(of: viewModel.didAutoStopAtGoal) { _, didStop in
                handleAutoStopChange(didStop)
            }
            .onChange(of: viewModel.isCompletedForDisplay) { _, isCompleted in
                handleCompletionChange(isCompleted)
            }
            .onAppear {
                handleOnAppear()
            }
            .onDisappear {
                handleOnDisappear()
            }
            .fullScreenCover(isPresented: $showFocusMode) {
                focusModeView
            }
            .onChange(of: viewModel.pendingJournalEntry) { _, newEntry in
                handleJournalEntryChange(newEntry)
            }
            .sheet(item: $journalCompletion) { completion in
                JournalEntrySheet(completion: completion) {
                    journalCompletion = nil
                }
            }
            .sheet(isPresented: $showingCustomLogPrompt) {
                customLogPromptSheet
            }
            .sheet(isPresented: $showingEditHabit) {
                HabitFormView(mode: .edit(habit))
            }
            .confirmationDialog("Delete Habit?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                deleteConfirmationActions
            } message: {
                Text("This will remove the habit and its future tracking. Past data remains available.")
            }
    }
    
    // MARK: - Computed Properties
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(viewModel.isCompletedForDisplay ? Color(hex: habit.colorHex ?? "#007AFF").opacity(colorScheme == .light ? 0.1 : 0.2) : Color.clear)
    }
    
    private var trailingSwipeActions: some View {
        Group {
            Button {
                _ = viewModel.prepareAdditionalReflection(createNewJournalEntry: true)
            } label: {
                Label("Add Journal Entry", systemImage: "book.pages")
            }
            .tint(Color(hex: habit.colorHex ?? "#007AFF"))

            Button {
                presentCustomLogPrompt()
            } label: {
                Label("Log Progress", systemImage: "plus.rectangle.on.rectangle")
            }
            .tint(Color(hex: habit.colorHex ?? "#007AFF"))
        }
        .disabled(habit.isEtherealHabit)

    }
    
    private var leadingSwipeActions: some View {
        Button {
            showingEditHabit = true
        } label: {
            Label("Edit", systemImage: "slider.horizontal.3")
        }
        .tint(Color(hex: habit.colorHex ?? "#007AFF"))
    }
    
    private var focusModeView: some View {
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
    
    private var customLogPromptSheet: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                CustomLogPromptView(
                    fieldLabel: customLogFieldLabel,
                    unitLabel: customLogUnitLabel,
                    valueText: $customLogValueText,
                    validationMessage: customLogValidationMessage,
                    allowsDecimal: allowsDecimalInput,
                    onCancel: { showingCustomLogPrompt = false },
                    onSave: { attemptCustomLogSave() }
                )
                .padding(.top, 16)
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .presentationDetents([.fraction(0.3), .medium])
        .presentationDragIndicator(.hidden)
    }
    
    private var deleteConfirmationActions: some View {
        Group {
            Button("Delete", role: .destructive) {
                onDelete(habit)
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    // MARK: - Helper Properties
    
    private var customLogFieldLabel: String {
        if habit.isTimerHabit { return "Minutes" }
        if habit.isRoutineHabit { return "Steps" }
        return habit.metricUnit ?? "Amount"
    }

    private var customLogUnitLabel: String? {
        if habit.isTimerHabit { return "min" }
        if habit.isRoutineHabit { return nil }
        return habit.metricUnit
    }

    private var allowsDecimalInput: Bool {
        if habit.isTimerHabit { return true }
        if habit.isRoutineHabit { return false }
        return habit.metricValue.truncatingRemainder(dividingBy: 1) != 0
    }
    
    // MARK: - Event Handlers
    
    private func handleAutoStopChange(_ didStop: Bool) {
        if didStop, showFocusMode {
            // Close focus mode when the goal is reached automatically
            showFocusMode = false
            // Reset the flag after handling
            viewModel.didAutoStopAtGoal = false
        }
    }
    
    private func handleCompletionChange(_ isCompleted: Bool) {
        if !isCompleted {
            hasShownJournalForCurrentCompletion = false
        }
    }
    
    private func handleOnAppear() {
        // Provide Core Data context to the view model
        viewModel.setContext(viewContext)
        if !viewModel.isCompletedForDisplay {
            hasShownJournalForCurrentCompletion = false
        }
    }
    
    private func handleOnDisappear() {
        // Clean up timer if this view disappears
        if viewModel.isTimerRunning { 
            viewModel.pauseTimer(saveProgress: true)
            activeTimerHabit = nil 
        }
    }
    
    private func handleJournalEntryChange(_ newEntry: HabitCompletion?) {
        guard let entry = newEntry else { return }

        if entry.isJournalOnly {
            journalCompletion = entry
        } else if !viewModel.isCompletedForDisplay || !hasShownJournalForCurrentCompletion {
            journalCompletion = entry
            hasShownJournalForCurrentCompletion = true
        }

        viewModel.pendingJournalEntry = nil
    }
}
