//
//  gamified_habit_trackerApp.swift
//  gamified-habit-tracker
//
//  Created by Andrew Yin on 9/5/25.
//

import SwiftUI

@main
struct gamified_habit_trackerApp: App {
    let persistenceController = PersistenceController.shared
    init() {
        HabitWidgetExporter.shared.bootstrap(using: persistenceController.container.viewContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
