//
//  timerVisualBundle.swift
//  timerVisual
//
//  Created by Andrew Yin on 9/12/25.
//

import WidgetKit
import SwiftUI

@main
struct timerVisualBundle: WidgetBundle {
    var body: some Widget {
        timerVisual()
        timerVisualControl()
        if #available(iOSApplicationExtension 16.1, *) {
            HabitTimerLiveActivity()
        }
    }
}
