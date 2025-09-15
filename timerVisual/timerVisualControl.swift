////
////  timerVisualControl.swift
////  timerVisual
////
////  Control Widget to start/stop a habit timer via App Intent.
////
//
//import AppIntents
//import SwiftUI
//import WidgetKit
//import AppIntentsKit
//
//
//@available(iOSApplicationExtension 18.0, *)
//struct timerVisualControl: ControlWidget {
//    static let kind = "yin.gamified-habit-tracker.timerVisual"
//
//    var body: some ControlWidgetConfiguration {
//        AppIntentControlConfiguration<TimerConfiguration, TimerControlTemplate>(
//            kind: Self.kind,
//            provider: Provider()
//        ) { (value: Value) -> TimerControlTemplate in
//            return TimerControlTemplate(value: value)
//        }
//        .displayName("Timer")
//        .description("Start or stop a habit timer")
//    }
//}
//
//@available(iOSApplicationExtension 18.0, *)
//extension timerVisualControl {
//    struct Value { let isRunning: Bool; let habitId: String }
//
//    struct Provider: AppIntentControlValueProvider {
//        typealias Configuration = TimerConfiguration
//        typealias Value = timerVisualControl.Value
//
//        func previewValue(configuration: TimerConfiguration) -> Value {
//            Value(isRunning: false, habitId: configuration.timerHabitId)
//        }
//
//        func currentValue(configuration: TimerConfiguration) async throws -> Value {
//            // TODO: Query shared storage for real running status of the habit
//            Value(isRunning: false, habitId: configuration.timerHabitId)
//        }
//    }
//}
//
//@available(iOSApplicationExtension 18.0, *)
//struct TimerControlTemplate: ControlWidgetTemplate {
//    let value: timerVisualControl.Value
//
//    var body: some ControlWidgetTemplate {
//        ControlWidgetButton<ToggleHabitTimerIntent, timerVisualControl.Value, TimerConfiguration>(value) {
//            Label(value.isRunning ? "On" : "Off", systemImage: "timer")
//        }
//    }
//}
//
//@available(iOSApplicationExtension 18.0, *)
//struct TimerConfiguration: ControlConfigurationIntent {
//    static let title: LocalizedStringResource = "Timer"
//    @Parameter(title: "Habit ID", default: "") var timerHabitId: String
//}
