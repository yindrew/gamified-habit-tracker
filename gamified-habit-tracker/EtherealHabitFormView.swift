import SwiftUI
import CoreData

struct EtherealHabitQuickAddView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var details: String = ""
    @State private var showValidationError = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case description
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Task name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                        .focused($focusedField, equals: .name)

                    TextField("Description (optional)", text: $details, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.sentences)
                        .focused($focusedField, equals: .description)
                }

                if showValidationError {
                    Section {
                        Text("Please provide a name before creating this habit.")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Quick Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createHabit() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                focusedField = .name
            }
        }
    }

    private func createHabit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showValidationError = true
            focusedField = .name
            return
        }

        let habit = Habit(context: viewContext)
        habit.id = UUID()
        habit.name = trimmedName

        let trimmedDescription = details.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.habitDescription = trimmedDescription.isEmpty ? nil : trimmedDescription

        habit.icon = "sparkles"
        habit.colorHex = "#8E8CF2"
        habit.targetFrequency = 1
        habit.metricValue = 1
        habit.metricUnit = "task"
        habit.goalValue = 1
        habit.currentStreak = 0
        habit.longestStreak = 0
        habit.totalCompletions = 0
        habit.createdDate = Date()
        habit.lastCompletedDate = nil
        habit.isActive = true
        habit.notificationsEnabled = false
        habit.notificationTime = nil
        habit.schedule = .daily
        habit.habitType = "ethereal"

        do {
            try viewContext.save()
            HabitWidgetExporter.shared.scheduleSync(using: viewContext)
            dismiss()
        } catch {
            #if DEBUG
            print("[QuickAdd] Failed to create ethereal habit: \(error)")
            #endif
        }
    }
}
