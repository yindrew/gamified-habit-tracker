////
////  timerVisual.swift
////  timerVisual
////
////  Habit summary widget with interactive controls for incrementing and
////  pausing/resuming timers.
////
//
//import WidgetKit
//import SwiftUI
//import SharedTimerModels
//
//@available(iOSApplicationExtension 17.0, *)
//struct HabitWidgetEntry: TimelineEntry {
//    let date: Date
//    let configuration: HabitWidgetConfigurationIntent
//    let snapshot: HabitWidgetSnapshot
//}
//
//@available(iOSApplicationExtension 17.0, *)
//struct HabitWidgetProvider: AppIntentTimelineProvider {
//    func placeholder(in context: Context) -> HabitWidgetEntry {
//        HabitWidgetEntry(
//            date: Date(),
//            configuration: HabitWidgetConfigurationIntent(),
//            snapshot: HabitWidgetSnapshot.placeholder
//        )
//    }
//
//    func snapshot(for configuration: HabitWidgetConfigurationIntent, in context: Context) async -> HabitWidgetEntry {
//        let selectedHabit = configuration.habit ?? .placeholder
//        let snapshot = HabitWidgetDataStore().snapshot(for: selectedHabit.id) ?? HabitWidgetSnapshot.placeholder
//        return HabitWidgetEntry(date: Date(), configuration: configuration, snapshot: snapshot)
//    }
//
//    func timeline(for configuration: HabitWidgetConfigurationIntent, in context: Context) async -> Timeline<HabitWidgetEntry> {
//        let selectedHabit = configuration.habit ?? .placeholder
//        let snapshot = HabitWidgetDataStore().snapshot(for: selectedHabit.id) ?? HabitWidgetSnapshot.placeholder
//        let entry = HabitWidgetEntry(date: Date(), configuration: configuration, snapshot: snapshot)
//        // Refresh every 15 minutes to pick up new progress.
//        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
//        return Timeline(entries: [entry], policy: .after(next))
//    }
//}
//
//@available(iOSApplicationExtension 17.0, *)
//struct HabitWidgetEntryView: View {
//    var entry: HabitWidgetProvider.Entry
//
//    private var themeColor: Color { Color(hex: entry.snapshot.colorHex) }
//
//    var body: some View {
//        ZStack {
//            themeColor.opacity(0.1)
//            VStack(alignment: .leading, spacing: 10) {
//                header
//                Spacer(minLength: 4)
//                footer
//            }
//            .padding(14)
//        }
//    }
//
//    private var header: some View {
//        HStack(spacing: 8) {
//            ZStack {
//                Circle().fill(themeColor.opacity(0.15))
//                Image(systemName: entry.snapshot.icon)
//                    .font(.system(size: 16, weight: .semibold))
//                    .foregroundColor(themeColor)
//            }
//            .frame(width: 32, height: 32)
//            Text(entry.snapshot.name)
//                .font(.headline)
//                .foregroundColor(.primary)
//                .lineLimit(1)
//            Spacer()
//        }
//    }
//
//    private var footer: some View {
//        HStack(alignment: .center, spacing: 12) {
//            ProgressRing(progress: entry.snapshot.progress, color: themeColor) {
//                VStack(spacing: 2) {
//                    Text(entry.snapshot.mode == .timer ? "Time" : "Today")
//                        .font(.caption2)
//                        .foregroundColor(.secondary)
//                    Text(entry.snapshot.formattedProgress)
//                        .font(.caption)
//                        .fontWeight(.semibold)
//                        .multilineTextAlignment(.center)
//                        .minimumScaleFactor(0.7)
//                }
//            }
//            .frame(width: 70, height: 70)
//
//            Spacer(minLength: 0)
//
//            if entry.snapshot.mode == .timer {
//                TimerActionButton(snapshot: entry.snapshot, color: themeColor)
//            } else {
//                IncrementActionButton(snapshot: entry.snapshot, color: themeColor)
//            }
//        }
//    }
//}
//
//@available(iOSApplicationExtension 17.0, *)
//private struct ProgressRing<Content: View>: View {
//    let progress: Double
//    let color: Color
//    @ViewBuilder var content: () -> Content
//
//    var body: some View {
//        ZStack {
//            Circle()
//                .stroke(color.opacity(0.15), lineWidth: 8)
//            Circle()
//                .trim(from: 0, to: progress)
//                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
//                .rotationEffect(.degrees(-90))
//            content()
//        }
//    }
//}
//
//@available(iOSApplicationExtension 17.0, *)
//private struct IncrementActionButton: View {
//    let snapshot: HabitWidgetSnapshot
//    let color: Color
//
//    var body: some View {
//        Button(intent: IncrementHabitIntent(habitId: snapshot.id)) {
//            Image(systemName: "plus")
//                .font(.system(size: 18, weight: .bold))
//                .foregroundStyle(.white)
//                .frame(width: 44, height: 44)
//                .background(color)
//                .clipShape(Circle())
//        }
//        .buttonStyle(.plain)
//        .accessibilityLabel("Increment \(snapshot.name)")
//    }
//}
//
//@available(iOSApplicationExtension 17.0, *)
//private struct TimerActionButton: View {
//    let snapshot: HabitWidgetSnapshot
//    let color: Color
//
//    var body: some View {
//        let isRunning = snapshot.isTimerRunning ?? false
//        let symbol = isRunning ? "pause.fill" : "play.fill"
//        Button(intent: ToggleHabitTimerIntent(habitId: snapshot.id, shouldRun: !isRunning)) {
//            Image(systemName: symbol)
//                .font(.system(size: 18, weight: .bold))
//                .foregroundStyle(.white)
//                .frame(width: 44, height: 44)
//                .background(color)
//                .clipShape(Circle())
//        }
//        .buttonStyle(.plain)
//        .accessibilityLabel(isRunning ? "Pause timer" : "Start timer")
//    }
//}
//
//struct timerVisual: Widget {
//    let kind: String = "timerVisual"
//
//    var body: some WidgetConfiguration {
//        if #available(iOSApplicationExtension 17.0, *) {
//            return AppIntentConfiguration(kind: kind, intent: HabitWidgetConfigurationIntent.self, provider: HabitWidgetProvider()) { entry in
//                HabitWidgetEntryView(entry: entry)
//                    .containerBackground(.fill.tertiary, for: .widget)
//            }
//            .configurationDisplayName("Habit Progress")
//            .description("Stay on top of your daily habit goals.")
//            .supportedFamilies([.systemSmall])
//        } else {
//            return StaticConfiguration(kind: kind, provider: LegacyProvider()) { entry in
//                LegacyEntryView(entry: entry)
//            }
//            .configurationDisplayName("Habit Progress")
//            .description("Stay on top of your daily habit goals.")
//        }
//    }
//}
//
//// MARK: - Legacy fallback (iOS 16)
//private struct LegacyEntry: TimelineEntry {
//    let date: Date
//}
//
//private struct LegacyProvider: TimelineProvider {
//    func placeholder(in context: Context) -> LegacyEntry { LegacyEntry(date: Date()) }
//    func getSnapshot(in context: Context, completion: @escaping (LegacyEntry) -> Void) { completion(placeholder(in: context)) }
//    func getTimeline(in context: Context, completion: @escaping (Timeline<LegacyEntry>) -> Void) {
//        completion(Timeline(entries: [LegacyEntry(date: Date())], policy: .never))
//    }
//}
//
//private struct LegacyEntryView: View {
//    let entry: LegacyEntry
//    var body: some View {
//        VStack(alignment: .leading) {
//            Text("Upgrade to iOS 17")
//                .font(.headline)
//            Text("Enable interactive widgets to track habits here.")
//                .font(.caption)
//                .foregroundColor(.secondary)
//        }
//        .padding()
//    }
//}
//
//#Preview(as: .systemSmall) {
//    if #available(iOS 17.0, *) {
//        timerVisual()
//    } else {
//        timerVisual()
//    }
//} timeline: {
//    HabitWidgetEntry(
//        date: .now,
//        configuration: HabitWidgetConfigurationIntent(),
//        snapshot: .placeholder
//    )
//    HabitWidgetEntry(
//        date: .now,
//        configuration: HabitWidgetConfigurationIntent(),
//        snapshot: .sampleTimer
//    )
//}
