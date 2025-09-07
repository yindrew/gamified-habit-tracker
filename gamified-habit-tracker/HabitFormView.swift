//
//  HabitFormView.swift
//  gamified-habit-tracker
//
//  Created by Andrew Yin on 9/5/25.
//

import SwiftUI
import CoreData

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
    
    // Scheduling
    @State private var selectedSchedule: ScheduleType = .daily
    @State private var selectedWeekdays: Set<Int> = []
    @State private var selectedMonthDays: Set<Int> = []
    
    // Coping Plan
    @State private var copingPlan: String = ""
    
    let availableIcons = ["star", "heart", "bolt", "leaf", "flame", "drop", "moon", "sun.max", "figure.run", "book", "music.note", "paintbrush", "camera", "gamecontroller"]
    let availableColors: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .yellow, .indigo, .mint, .cyan]
    
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
            
            // Initialize scheduling
            self._selectedSchedule = State(initialValue: habit.schedule)
            self._selectedWeekdays = State(initialValue: Set(habit.weeklyScheduleDays))
            self._selectedMonthDays = State(initialValue: Set(habit.monthlyScheduleDays))
            
            // Initialize coping plan
            self._copingPlan = State(initialValue: habit.copingPlan ?? "")
        }
    }
    
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    private var navigationTitle: String {
        isEditing ? "Edit Habit" : "New Habit"
    }
    
    private var saveButtonText: String {
        isEditing ? "Save" : "Create"
    }
    
    var body: some View {
        NavigationView {
            Form {
                habitDetailsSection
                customizationSection
                scheduleSection
                copingPlanSection
                goalSection
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(saveButtonText) {
                        saveHabit()
                    }
                    .disabled(habitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
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
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Color")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                    ForEach(availableColors, id: \.self) { color in
                        Button(action: { selectedColor = color }) {
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
            .onChange(of: selectedSchedule) { newSchedule in
                // Clear schedule selections when switching types
                if newSchedule != .weekly {
                    selectedWeekdays.removeAll()
                }
                if newSchedule != .monthly {
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
    
    private var copingPlanSection: some View {
        Section(header: Text("Coping Plan"), footer: Text("A simpler alternative you can do if you miss your scheduled habit. Completing it the next day maintains your streak.")) {
            TextField("e.g., Do 5 push-ups instead of full workout", text: $copingPlan, axis: .vertical)
                .lineLimit(2...4)
                .textInputAutocapitalization(.sentences)
        }
    }
    
    private var goalSection: some View {
        Section(header: Text("Goal")) {
            if selectedSchedule == .daily {
                Stepper("Complete \(targetFrequency) time\(targetFrequency == 1 ? "" : "s") per day", value: $targetFrequency, in: 1...10)
            } else {
                Stepper("Complete \(targetFrequency) time\(targetFrequency == 1 ? "" : "s") on scheduled days", value: $targetFrequency, in: 1...10)
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveHabit() {
        withAnimation {
            switch mode {
            case .add:
                createNewHabit()
            case .edit(let habit):
                updateExistingHabit(habit)
            }
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
        newHabit.targetFrequency = Int32(targetFrequency)
        newHabit.currentStreak = 0
        newHabit.longestStreak = 0
        newHabit.totalCompletions = 0
        newHabit.createdDate = Date()
        newHabit.lastCompletedDate = nil
        newHabit.isActive = true
        
        // Set scheduling
        newHabit.schedule = selectedSchedule
        setScheduleValues(for: newHabit)
        
        // Set coping plan
        let trimmedCopingPlan = copingPlan.trimmingCharacters(in: .whitespacesAndNewlines)
        newHabit.copingPlan = trimmedCopingPlan.isEmpty ? nil : trimmedCopingPlan
        
        saveContext()
    }
    
    private func updateExistingHabit(_ habit: Habit) {
        habit.name = habitName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = habitDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.habitDescription = trimmedDescription.isEmpty ? nil : trimmedDescription
        habit.icon = selectedIcon
        habit.colorHex = selectedColor.toHex()
        habit.targetFrequency = Int32(targetFrequency)
        
        // Set scheduling
        habit.schedule = selectedSchedule
        setScheduleValues(for: habit)
        
        // Set coping plan
        let trimmedCopingPlan = copingPlan.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.copingPlan = trimmedCopingPlan.isEmpty ? nil : trimmedCopingPlan
        
        saveContext()
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

extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255)
        return String(format: "#%06x", rgb)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    HabitFormView(mode: .add)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
