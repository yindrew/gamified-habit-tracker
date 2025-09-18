//
//  timerVisualBundle.swift
//  timerVisual
//
//  Created by Andrew Yin on 9/12/25.
//

import WidgetKit
import SwiftUI
import AppIntents

@main
struct timerVisualBundle: WidgetBundle {
    init() {
        // Force-load the intent type in the widget extension
        if #available(iOSApplicationExtension 16.1, *) {
            _ = ToggleHabitTimerIntent.self
            print("🎯 Widget Bundle: ToggleHabitTimerIntent loaded")
        }
    }
    
    var body: some Widget {
//        timerVisual()
//        timerVisualControl()
        if #available(iOSApplicationExtension 16.1, *) {
            HabitTimerLiveActivity()
        }
    }
}
