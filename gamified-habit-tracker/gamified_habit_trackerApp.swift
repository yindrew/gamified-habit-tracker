//
//  gamified_habit_trackerApp.swift
//  gamified-habit-tracker
//
//  Created by Andrew Yin on 9/5/25.
//

import SwiftUI
import AppIntentsKit

@main
struct gamified_habit_trackerApp: App {
    let persistenceController = PersistenceController.shared
    init() {
        // Wire AppIntents bridge to our controller
        HabitTimerBridge.controller = TimerIntentController.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
