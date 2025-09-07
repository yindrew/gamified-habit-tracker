//
//  Persistence.swift
//  gamified-habit-tracker
//
//  Created by Andrew Yin on 9/5/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample habits for preview
        let sampleHabits = [
            ("Drink Water", "Stay hydrated throughout the day", "drop.fill", "#007AFF", 8, ScheduleType.daily, "Have a glass of water if you missed your goal"),
            ("Exercise", "Get moving for at least 30 minutes", "figure.run", "#FF3B30", 1, ScheduleType.weekdaysOnly, "Do 10 push-ups or take a 5-minute walk"),
            ("Read", "Read for personal growth", "book.fill", "#34C759", 1, ScheduleType.weekly, "Read just one page or listen to a podcast"),
            ("Meditate", "Practice mindfulness", "leaf.fill", "#AF52DE", 1, ScheduleType.weekendsOnly, "Take 3 deep breaths mindfully")
        ]
        
        for (name, description, icon, colorHex, frequency, scheduleType, copingPlan) in sampleHabits {
            let habit = Habit(context: viewContext)
            habit.id = UUID()
            habit.name = name
            habit.habitDescription = description
            habit.icon = icon
            habit.colorHex = colorHex
            habit.targetFrequency = Int32(frequency)
            habit.currentStreak = Int32.random(in: 0...15)
            habit.longestStreak = max(habit.currentStreak, Int32.random(in: 5...30))
            habit.totalCompletions = Int32.random(in: 10...100)
            habit.createdDate = Date().addingTimeInterval(-Double.random(in: 86400...2592000)) // 1 day to 30 days ago
            habit.isActive = true
            
            // Set scheduling
            habit.schedule = scheduleType
            habit.copingPlan = copingPlan
            
            // Add some completion records
            for i in 0..<Int.random(in: 1...5) {
                let completion = HabitCompletion(context: viewContext)
                completion.id = UUID()
                completion.completedDate = Date().addingTimeInterval(-Double(i * 86400))
                completion.habit = habit
            }
        }
        
        // Sample items removed - using habits now
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "gamified_habit_tracker")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
