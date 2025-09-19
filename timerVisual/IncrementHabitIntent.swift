////
////  IncrementHabitIntent.swift
////  timerVisual
////
////  Widget-side stub so the extension can reference the intent type when
////  rendering buttons. The main app target provides the real implementation.
////
//
//import AppIntents
//
//@available(iOSApplicationExtension 17.0, *)
//public struct IncrementHabitIntent: AppIntent {
//    public static var title: LocalizedStringResource { "Increment Habit" }
//    public static var description = IntentDescription("Increase today's progress for a habit.")
//    public static var openAppWhenRun: Bool { false }
//
//    @Parameter(title: "Habit ID")
//    public var habitId: String
//
//    public init() {
//        habitId = ""
//    }
//
//    public init(habitId: String) {
//        self.habitId = habitId
//    }
//
//    public func perform() async throws -> some IntentResult {
//        // No-op in the widget extension. The main app target executes the intent.
//        return .result()
//    }
//}
