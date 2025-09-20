 //
 //  HabitWidgetExporter.swift
 //  gamified-habit-tracker
 //
 //  Serialises Habit objects into lightweight snapshots for widget consumption
 //  and keeps WidgetKit timelines up to date.
 //

 import Foundation
 import CoreData
 import WidgetKit
 import SharedTimerModels

 final class HabitWidgetExporter {
     static let shared = HabitWidgetExporter()

     private let encoder: JSONEncoder = {
         let encoder = JSONEncoder()
         encoder.dateEncodingStrategy = .iso8601
         return encoder
     }()

     private let queue = DispatchQueue(label: "HabitWidgetExporter", qos: .utility)

     private init() {}

     func scheduleSync(using context: NSManagedObjectContext) {
         queue.async { [weak self, weak context] in
             guard let self, let context else { return }
             do {
                 let snapshots = try context.performAndWait { try self.fetchSnapshots(context: context) }
                 try self.persist(snapshots: snapshots)
             } catch {
                 #if DEBUG
                 print("[WidgetExporter] Failed to sync snapshots: \(error)")
                 #endif
             }
         }
     }

     func bootstrap(using context: NSManagedObjectContext) {
         scheduleSync(using: context)
     }

     private func fetchSnapshots(context: NSManagedObjectContext) throws -> [HabitWidgetSnapshot] {
         let request = NSFetchRequest<Habit>(entityName: "Habit")
         request.predicate = NSPredicate(format: "isActive == YES")
         let habits = try context.fetch(request)
         return habits.compactMap { HabitWidgetSnapshot(habit: $0) }
     }

     private func persist(snapshots: [HabitWidgetSnapshot]) throws {
         let data = try encoder.encode(snapshots)
         let defaults: UserDefaults
         if let shared = UserDefaults(suiteName: HabitWidgetStoreConstants.suiteName) {
             defaults = shared
         } else {
             #if DEBUG
             print("[WidgetExporter] App Group not configured; using standard UserDefaults. Widget data may be stale.")
             #endif
             defaults = .standard
         }
         defaults.set(data, forKey: HabitWidgetStoreConstants.snapshotsKey)
         DispatchQueue.main.async {
             WidgetCenter.shared.reloadTimelines(ofKind: "timerVisual")
         }
     }
 }

 private extension HabitWidgetSnapshot {
     init?(habit: Habit) {
         guard let id = habit.id?.uuidString else { return nil }
         let name = habit.name ?? "Habit"
         let icon = habit.icon ?? "star"
         let colorHex = habit.colorHex ?? "#007AFF"
         let goalValue = max(habit.goalValue, 0)
         let unitLabel = habit.metricUnit
         let now = Date()

         if habit.isTimerHabit {
             let totalMinutes = habit.timerMinutesToday
             self = HabitWidgetSnapshot(
                 id: id,
                 name: name,
                 icon: icon,
                 colorHex: colorHex,
                 mode: .timer,
                 value: totalMinutes,
                 goal: max(goalValue, 0.01),
                 unitLabel: unitLabel,
                 isTimerRunning: HabitTimerManager.existingManager(for: id)?.isRunning ?? false,
                 lastUpdated: now
             )
         } else {
             let value = habit.currentProgress
             let goal = max(goalValue, 1)
             self = HabitWidgetSnapshot(
                 id: id,
                 name: name,
                 icon: icon,
                 colorHex: colorHex,
                 mode: .count,
                 value: value,
                 goal: goal,
                 unitLabel: unitLabel,
                 isTimerRunning: nil,
                 lastUpdated: now
             )
         }
     }
 }
