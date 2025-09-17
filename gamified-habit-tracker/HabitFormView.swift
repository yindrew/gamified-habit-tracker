//
//  HabitFormView.swift
//  gamified-habit-tracker
//
//  Created by Andrew Yin on 9/5/25.
//

import SwiftUI
import CoreData
import UIKit
import UserNotifications

struct HabitFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // Mode determines behavior
    enum Mode {
        case add
        case edit(Habit)
    }
    
    let mode: Mode
    
    // Form state
    @State private var habitName: String = ""
    @State private var habitDescription: String = ""
    @State private var selectedColor: Color = .blue
    @State private var selectedIcon: String = "star"
    @State private var targetFrequency: Int = 1
    @State private var showingIconPicker = false
    @State private var showingColorPicker = false
    
    // Metrics
    @State private var metricValue: Double = 1.0
    @State private var metricUnit: String = "times"
    @State private var goalValue: Double = 1.0
    
    // Scheduling
    @State private var selectedSchedule: ScheduleType = .daily
    @State private var selectedWeekdays: Set<Int> = []
    @State private var selectedMonthDays: Set<Int> = []
    
    // Notifications
    @State private var notificationsEnabled: Bool = false
    @State private var notificationTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var showNotificationDeniedAlert: Bool = false
    
    // Coping Plan
    @State private var copingPlan: String = ""
    
    // Habit Type
    @State private var habitType: HabitType = .frequency
    @State private var routineSteps: [String] = [""]
    
    // Timer
    @State private var timerHours: Int = 0
    @State private var timerMinutes: Int = 30
    @State private var timerSeconds: Int = 0
    @State private var timerDurationSeconds: TimeInterval = 30 * 60

    // Focus management for routine step TextFields
    @FocusState private var focusedRoutineIndex: Int?
    
    enum HabitType: String, CaseIterable {
        case frequency = "frequency"
        case routine = "routine"
        case timer = "timer"
        case ethereal = "ethereal"
        
        var displayName: String {
            switch self {
            case .frequency: return "Frequency"
            case .routine: return "Routine"
            case .timer: return "Timer"
            case .ethereal: return "Quick Task"
            }
        }
        
        var description: String {
            switch self {
            case .frequency: return "Track how many times you do an action"
            case .routine: return "Complete a sequence of steps in order"
            case .timer: return "Track time spent on an activity"
            case .ethereal: return "Complete once and archive automatically"
            }
        }
        
        var icon: String {
            switch self {
            case .frequency: return "number"
            case .routine: return "checklist"
            case .timer: return "timer"
            case .ethereal: return "sparkles"
            }
        }
        
        static var selectableCases: [HabitType] { [.frequency, .routine, .timer] }
        var isSelectable: Bool { HabitType.selectableCases.contains(self) }
    }

    // Preview-safe detection to avoid system interactions in Xcode canvas
    private var isRunningInPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    let availableIcons = ["star", "heart", "bolt", "leaf", "flame", "drop", "moon", "sun.max", "figure.run", "book", "music.note", "paintbrush", "camera", "gamecontroller", "dumbbell", "bicycle", "car", "airplane", "house", "briefcase", "graduationcap", "stethoscope", "wrench", "hammer", "scissors", "pencil", "cup.and.saucer", "fork.knife"]
    let availableColors: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .yellow, .indigo, .mint, .cyan, .gray, .black, .white, .brown, .teal]
    
    init(mode: Mode) {
        self.mode = mode
        
        // Initialize based on mode
        switch mode {
        case .add:
            // Keep default values
            break
        case .edit(let habit):
            self._habitName = State(initialValue: habit.name ?? "")
            self._habitDescription = State(initialValue: habit.habitDescription ?? "")
            self._selectedColor = State(initialValue: Color(hex: habit.colorHex ?? "#007AFF"))
            self._selectedIcon = State(initialValue: habit.icon ?? "star")
            self._targetFrequency = State(initialValue: Int(habit.targetFrequency))
            
            // Initialize metrics
            self._metricValue = State(initialValue: habit.metricValue)
            self._metricUnit = State(initialValue: habit.metricUnit ?? "times")
            self._goalValue = State(initialValue: habit.goalValue)
            
            // Initialize scheduling
            self._selectedSchedule = State(initialValue: habit.schedule)
            self._selectedWeekdays = State(initialValue: Set(habit.weeklyScheduleDays))
            self._selectedMonthDays = State(initialValue: Set(habit.monthlyScheduleDays))
            
            // Initialize coping plan
            self._copingPlan = State(initialValue: habit.copingPlan ?? "")
            
            // Initialize notifications
            self._notificationsEnabled = State(initialValue: habit.notificationsEnabled)
            if let time = habit.notificationTime {
                self._notificationTime = State(initialValue: time)
            } else {
                let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
                self._notificationTime = State(initialValue: defaultTime)
            }
            
            // Initialize habit type and routine steps
            let existingHabitType = HabitType(rawValue: habit.habitType ?? "frequency") ?? .frequency
            self._habitType = State(initialValue: existingHabitType)
            
            if existingHabitType == .routine, let routineStepsString = habit.routineSteps {
                let steps = routineStepsString.components(separatedBy: "|||").filter { !$0.isEmpty }
                self._routineSteps = State(initialValue: steps.isEmpty ? [""] : steps)
            } else {
                self._routineSteps = State(initialValue: [""])
            }
            
            // Initialize timer duration (stored in goalValue as minutes; expose H/M/S)
            if existingHabitType == .timer {
                let totalSeconds = Int((habit.goalValue * 60.0).rounded())
                let h = totalSeconds / 3600
                let m = (totalSeconds % 3600) / 60
                let s = totalSeconds % 60
                self._timerHours = State(initialValue: h)
                self._timerMinutes = State(initialValue: m)
                self._timerSeconds = State(initialValue: s)
                self._timerDurationSeconds = State(initialValue: TimeInterval(totalSeconds))
            } else {
                self._timerHours = State(initialValue: 0)
                self._timerMinutes = State(initialValue: 30)
                self._timerSeconds = State(initialValue: 0)
                self._timerDurationSeconds = State(initialValue: 30 * 60)
            }
        }
    }
    
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    private var navigationTitle: String {
        isEditing ? "Edit Item" : "New Item"
    }
    
    private var saveButtonText: String {
        isEditing ? "Save" : "Create"
    }
    
    var body: some View {
        NavigationView {
            Form {
                habitDetailsSection
                customizationSection
                if habitType != .ethereal {
                    scheduleSection
                    notificationsSection
                    copingPlanSection
                }
                goalSection
            }
            // Dismiss keyboard on scroll/tap away
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(saveButtonText) { saveHabit() }
                    .disabled(isSaveDisabled)
                }
            }
            .alert("Notifications Disabled", isPresented: $showNotificationDeniedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please enable notifications in Settings to receive reminders.")
            }
        }
    }

    // MARK: - Validation
    private var hasAtLeastOneRoutineStep: Bool {
        // At least one non-empty step when type is routine
        guard habitType == .routine else { return true }
        return routineSteps.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var isSaveDisabled: Bool {
        let nameEmpty = habitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return nameEmpty || !hasAtLeastOneRoutineStep
    }
    
    // Helper for native picker summary
    private var timerGoalSummary: String {
        let totalSeconds = Int(timerDurationSeconds)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h)h") }
        if m > 0 { parts.append("\(m)m") }
        if s > 0 || parts.isEmpty { parts.append("\(s)s") }
        return parts.joined(separator: " ")
    }
    
    // MARK: - Form Sections
    
    private var habitDetailsSection: some View {
        Section(header: Text("Habit Details")) {
            TextField("Habit Name", text: $habitName)
                .textInputAutocapitalization(.words)
            
            TextField("Description (Optional)", text: $habitDescription, axis: .vertical)
                .lineLimit(3...6)
                .textInputAutocapitalization(.sentences)
        }
    }
    
    private var customizationSection: some View {
        Section(header: Text("Customization")) {
            HStack {
                Text("Icon")
                Spacer()
                Button(action: { showingIconPicker.toggle() }) {
                    Image(systemName: selectedIcon)
                        .foregroundColor(selectedColor)
                        .font(.title2)
                        .frame(width: 30, height: 30)
                        .background(selectedColor.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            if showingIconPicker {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            showingIconPicker = false
                        }) {
                            Image(systemName: icon)
                                .foregroundColor(selectedIcon == icon ? selectedColor : .gray)
                                .font(.title3)
                                .frame(width: 30, height: 30)
                                .background(selectedIcon == icon ? selectedColor.opacity(0.1) : Color.clear)
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 5)
            }
            
            HStack {
                Text("Color")
                Spacer()
                Button(action: { showingColorPicker.toggle() }) {
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            
            if showingColorPicker {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                    ForEach(availableColors, id: \.self) { color in
                        Button(action: {
                            selectedColor = color
                            showingColorPicker = false
                        }) {
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 5)
            }
        }
    }
    
    private var scheduleSection: some View {
        Section(header: Text("Schedule")) {
            Picker("Schedule Type", selection: $selectedSchedule) {
                ForEach(ScheduleType.allCases, id: \.self) { schedule in
                    HStack {
                        Image(systemName: schedule.icon)
                        Text(schedule.displayName)
                    }
                    .tag(schedule)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedSchedule) { oldValue, newValue in
                // Clear schedule selections when switching types
                if newValue != .weekly {
                    selectedWeekdays.removeAll()
                }
                if newValue != .monthly {
                    selectedMonthDays.removeAll()
                }
            }
            
            Text(selectedSchedule.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Weekly schedule picker
            if selectedSchedule == .weekly {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Days")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(1...7, id: \.self) { weekday in
                            let dayName = Calendar.current.shortWeekdaySymbols[(weekday - 1) % 7]
                            Button(action: {
                                if selectedWeekdays.contains(weekday) {
                                    selectedWeekdays.remove(weekday)
                                } else {
                                    selectedWeekdays.insert(weekday)
                                }
                            }) {
                                Text(dayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedWeekdays.contains(weekday) ? .white : selectedColor)
                                    .frame(width: 32, height: 32)
                                    .background(selectedWeekdays.contains(weekday) ? selectedColor : selectedColor.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            
            // Monthly schedule picker
            if selectedSchedule == .monthly {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Days of Month")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                        ForEach(1...31, id: \.self) { day in
                            Button(action: {
                                if selectedMonthDays.contains(day) {
                                    selectedMonthDays.remove(day)
                                } else {
                                    selectedMonthDays.insert(day)
                                }
                            }) {
                                Text("\(day)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedMonthDays.contains(day) ? .white : selectedColor)
                                    .frame(width: 28, height: 28)
                                    .background(selectedMonthDays.contains(day) ? selectedColor : selectedColor.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
    }
    
    private var notificationsSection: some View {
        Section(header: Text("Notifications"), footer: Text("Reminds you at the chosen time only on scheduled days.")) {
            Toggle(isOn: $notificationsEnabled) {
                Text("Enable Notifications")
            }
            
            if notificationsEnabled {
                if isRunningInPreviews {
                    // In Xcode previews, avoid interactive DatePicker to prevent focus issues
                    HStack {
                        Text("Time of Day")
                        Spacer()
                        Text(notificationTime, style: .time)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Use wheel style to avoid focus issues with compact picker in Form/Sheet
                    DatePicker("Time of Day", selection: $notificationTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.wheel)
                }
            }
        }
        .disabled(isRunningInPreviews) // Keep section visible but non-interactive in previews
    }
    
    private var copingPlanSection: some View {
        Section(header: Text("Coping Plan"), footer: Text("A simpler alternative you can do if you miss your scheduled habit. Completing it the next day maintains your streak for streak over 7 days.")) {
            TextField("e.g., Do 5 push-ups instead of full workout", text: $copingPlan, axis: .vertical)
                .lineLimit(2...4)
                .textInputAutocapitalization(.sentences)
        }
    }
    
    private var goalSection: some View {
        Section(header: Text("Goal & Metrics")) {
            if habitType.isSelectable {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Habit Type")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 12) {
                        ForEach(HabitType.selectableCases, id: \.self) { type in
                            Button(action: {
                                habitType = type
                                if type == .routine && routineSteps.isEmpty {
                                    routineSteps = [""]
                                }
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: type.icon)
                                        .font(.title2)
                                        .foregroundColor(habitType == type ? .white : selectedColor)
                                    
                                    Text(type.displayName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(habitType == type ? .white : .primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(habitType == type ? selectedColor : selectedColor.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Text(habitType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if habitType == .frequency {
                    frequencyContent
                } else if habitType == .routine {
                    routineContent
                } else {
                    timerContent
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A one-off Task")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Complete this task once. When you mark it done, it disappears from your list.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var frequencyContent: some View {
        Group {
            // Metric Unit
            HStack {
                Text("Unit")
                Spacer()
                TextField("times", text: $metricUnit)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            
            // Metric Value (per completion)
            HStack {
                Text("Value per completion")
                Spacer()
                TextField("1.0", value: $metricValue, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                Text(metricUnit)
                    .foregroundColor(.secondary)
            }
            
            // Goal Value (total target)
            HStack {
                Text("Daily goal")
                Spacer()
                TextField("1.0", value: $goalValue, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                Text(metricUnit)
                    .foregroundColor(.secondary)
            }
            
            // Calculated completions needed
            if metricValue > 0 {
                let completionsNeeded = Int(ceil(goalValue / metricValue))
                Text("Requires \(completionsNeeded) completion\(completionsNeeded == 1 ? "" : "s") \(selectedSchedule == .daily ? "per day" : "on scheduled days")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var routineContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Routine Steps")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        addStep()
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(selectedColor)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            ForEach(routineSteps.indices, id: \.self) { index in
                HStack(spacing: 12) {
                    Text("\(index + 1).")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    
                    TextField("Enter step", text: $routineSteps[index])
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.next)
                        .focused($focusedRoutineIndex, equals: index)
                        .onSubmit {
                            if index == routineSteps.count - 1 {
                                addStep()
                            } else {
                                focusedRoutineIndex = index + 1
                            }
                        }
                    
                    if routineSteps.count > 1 {
                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.2)) {
                                removeStep(at: index) 
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                                .font(.title3)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            if !routineSteps.isEmpty {
                let missing = !hasAtLeastOneRoutineStep
                Text(missing ? "Add at least one step to save" : "Complete all steps to mark the routine as done")
                    .font(.caption)
                    .foregroundColor(missing ? .red : .secondary)
            }
        }
    }
    
    private var timerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Time Goal")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                CountdownDurationPicker(duration: $timerDurationSeconds)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Track time spent on this activity. Complete your daily goal by accumulating the target duration.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Routine Step Management
    
    private func addStep() {
        routineSteps.append("")
        // Focus the newly added step
        focusedRoutineIndex = routineSteps.count - 1
    }
    
    private func removeStep(at index: Int) {
        if routineSteps.count > 1 {
            routineSteps.remove(at: index)
        }
    }
    
    // MARK: - Actions
    
    private func saveHabit() {
        let proceedToSave: () -> Void = {
            withAnimation {
                switch mode {
                case .add:
                    createNewHabit()
                case .edit(let habit):
                    updateExistingHabit(habit)
                }
            }
        }

        // In Xcode previews, skip notification permission entirely
        if isRunningInPreviews {
            proceedToSave()
            return
        }

        if notificationsEnabled {
            NotificationManager.shared.requestAuthorizationIfNeeded { granted in
                DispatchQueue.main.async {
                    if granted {
                        proceedToSave()
                    } else {
                        notificationsEnabled = false
                        showNotificationDeniedAlert = true
                    }
                }
            }
        } else {
            proceedToSave()
        }
    }
    
    private func createNewHabit() {
        let newHabit = Habit(context: viewContext)
        newHabit.id = UUID()
        newHabit.name = habitName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = habitDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        newHabit.habitDescription = trimmedDescription.isEmpty ? nil : trimmedDescription
        newHabit.icon = selectedIcon
        newHabit.colorHex = selectedColor.toHex()
        newHabit.targetFrequency = Int32(ceil(goalValue / metricValue))
        if habitType == .ethereal {
            newHabit.targetFrequency = 1
        }
        newHabit.currentStreak = 0
        newHabit.longestStreak = 0
        newHabit.totalCompletions = 0
        newHabit.createdDate = Date()
        newHabit.lastCompletedDate = nil
        newHabit.isActive = true
        if habitType == .ethereal {
            newHabit.notificationsEnabled = false
            newHabit.notificationTime = nil
        } else {
            newHabit.notificationsEnabled = notificationsEnabled
            newHabit.notificationTime = notificationTime
        }
        
        // Set metrics (different for timer habits)
        if habitType == .timer {
            newHabit.metricValue = 1.0
            newHabit.metricUnit = "minutes"
            newHabit.goalValue = timerDurationSeconds / 60.0
        } else if habitType == .ethereal {
            newHabit.metricValue = 1.0
            newHabit.metricUnit = "task"
            newHabit.goalValue = 1.0
        } else {
            newHabit.metricValue = metricValue
            newHabit.metricUnit = metricUnit
            newHabit.goalValue = goalValue
        }
        
        // Set scheduling
        if habitType == .ethereal {
            newHabit.schedule = .daily
            newHabit.scheduleValue = 0
        } else {
            newHabit.schedule = selectedSchedule
            setScheduleValues(for: newHabit)
        }
        
        // Set coping plan
        let trimmedCopingPlan = copingPlan.trimmingCharacters(in: .whitespacesAndNewlines)
        newHabit.copingPlan = trimmedCopingPlan.isEmpty ? nil : trimmedCopingPlan
        
        // Set habit type and routine steps
        newHabit.habitType = habitType.rawValue
        if habitType == .routine {
            let validSteps = routineSteps.compactMap { step in
                let trimmed = step.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            newHabit.routineSteps = validSteps.isEmpty ? nil : validSteps.joined(separator: "|||")
        }
        
        saveContext()
        // Schedule or cancel notifications after saving
        if newHabit.notificationsEnabled {
            NotificationManager.shared.scheduleNotifications(for: newHabit)
        } else {
            NotificationManager.shared.cancelNotifications(for: newHabit)
        }
    }
    
    private func updateExistingHabit(_ habit: Habit) {
        habit.name = habitName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = habitDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.habitDescription = trimmedDescription.isEmpty ? nil : trimmedDescription
        habit.icon = selectedIcon
        habit.colorHex = selectedColor.toHex()
        habit.targetFrequency = Int32(ceil(goalValue / metricValue))
        if habitType == .ethereal {
            habit.targetFrequency = 1
        }
        if habitType == .ethereal {
            habit.notificationsEnabled = false
            habit.notificationTime = nil
        } else {
            habit.notificationsEnabled = notificationsEnabled
            habit.notificationTime = notificationTime
        }
        
        // Set metrics (different for timer habits)
        if habitType == .timer {
            habit.metricValue = 1.0
            habit.metricUnit = "minutes"
            habit.goalValue = timerDurationSeconds / 60.0
        } else if habitType == .ethereal {
            habit.metricValue = 1.0
            habit.metricUnit = "task"
            habit.goalValue = 1.0
        } else {
            habit.metricValue = metricValue
            habit.metricUnit = metricUnit
            habit.goalValue = goalValue
        }
        
        // Set scheduling
        if habitType == .ethereal {
            habit.schedule = .daily
            habit.scheduleValue = 0
        } else {
            habit.schedule = selectedSchedule
            setScheduleValues(for: habit)
        }
        
        // Set coping plan
        let trimmedCopingPlan = copingPlan.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.copingPlan = trimmedCopingPlan.isEmpty ? nil : trimmedCopingPlan
        
        // Set habit type and routine steps
        habit.habitType = habitType.rawValue
        if habitType == .routine {
            let validSteps = routineSteps.compactMap { step in
                let trimmed = step.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            habit.routineSteps = validSteps.isEmpty ? nil : validSteps.joined(separator: "|||")
        } else {
            habit.routineSteps = nil
        }
        
        saveContext()
        // Update notifications to match latest config
        if habit.notificationsEnabled {
            NotificationManager.shared.scheduleNotifications(for: habit)
        } else {
            NotificationManager.shared.cancelNotifications(for: habit)
        }
    }
    
    private func setScheduleValues(for habit: Habit) {
        switch selectedSchedule {
        case .weekly:
            habit.setWeeklySchedule(weekdays: Array(selectedWeekdays))
        case .monthly:
            habit.setMonthlySchedule(days: Array(selectedMonthDays))
        default:
            habit.scheduleValue = 0
        }
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
            dismiss()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

// MARK: - Color Extensions

// Native iOS countdown timer picker (UIDatePicker in .countDownTimer mode)
struct CountdownDurationPicker: UIViewRepresentable {
    @Binding var duration: TimeInterval

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .countDownTimer
        picker.preferredDatePickerStyle = .wheels
        picker.countDownDuration = max(0, min(duration, 24 * 60 * 60))
        picker.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        // Keep UI in sync if external changes occur
        if abs(uiView.countDownDuration - duration) > 0.5 {
            uiView.countDownDuration = max(0, min(duration, 24 * 60 * 60))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject {
        var parent: CountdownDurationPicker
        init(_ parent: CountdownDurationPicker) { self.parent = parent }

        @objc func valueChanged(_ sender: UIDatePicker) {
            parent.duration = sender.countDownDuration
        }
    }
}

#Preview {
    HabitFormView(mode: .add)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
