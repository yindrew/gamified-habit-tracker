//
//  timerVisualLiveActivity.swift
//  timerVisual
//
//  Created by Andrew Yin on 9/12/25.
//

import ActivityKit
import WidgetKit
import SwiftUI
import SharedTimerModels
import AppIntents

// Force load the intent at module level
@available(iOS 16.1, *)
private let _intentLoader = ToggleHabitTimerIntent.self

@available(iOS 16.1, *)
struct HabitTimerLiveActivity: Widget {
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            // Lock Screen / Notification Center
            let color = Color(hex: context.attributes.colorHex)
            let goal = max(context.attributes.targetGoalSeconds, 1)
            let base = max(0, context.state.baseElapsedSeconds)
            let start = context.state.sessionStartDate
            let effectiveStart = start?.addingTimeInterval(TimeInterval(-base))

            HStack(alignment: .center, spacing: 12) {
                // Left content: icon + name, then progress bar + times
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(color.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: context.attributes.icon)
                                .foregroundColor(color)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(context.attributes.name)
                            .font(.headline)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                    }
                    if let s = effectiveStart {
                        let end = s.addingTimeInterval(TimeInterval(goal))
                        ProgressView(timerInterval: s...end, countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                            .progressViewStyle(.linear)
                            .tint(color)
                            .accessibilityLabel("Elapsed time")
                    } else {
                        ProgressView(value: min(Double(base), Double(goal)), total: Double(goal))
                            .progressViewStyle(.linear)
                            .tint(color)
                            .accessibilityLabel("Elapsed time")
                    }
                    HStack(spacing: 10) {
                        // Elapsed on the left under the bar
                        displayNumericTime(base: base, goal: goal, effectiveStart: effectiveStart)
                            .font(.caption)
                            .monospacedDigit()
                            .numericTextTransition()
                        Spacer(minLength: 0)
                    }
                }
                // Right content: large play/pause button occupying right side
                VStack {
                    Spacer(minLength: 0)
                    PlayPauseControl(habitId: context.attributes.habitId, isRunning: context.state.isRunning, color: color)
                        .scaleEffect(1.25)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

        } dynamicIsland: { context in
            DynamicIsland {
                let color = Color(hex: context.attributes.colorHex)
                let goal = max(context.attributes.targetGoalSeconds, 1)
                let base = max(0, context.state.baseElapsedSeconds)
                let start = context.state.sessionStartDate
                let effectiveStart = start?.addingTimeInterval(TimeInterval(-base))
                let isRunning = context.state.isRunning

                DynamicIslandExpandedRegion(.leading) {}
                DynamicIslandExpandedRegion(.trailing) {}
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Label {
                                Text(context.attributes.name)
                                    .font(.headline)
                            } icon: {
                                Image(systemName: context.attributes.icon)
                                    .foregroundColor(Color(hex: context.attributes.colorHex))
                            }
                            Spacer()
                        }
                        // Progress + action button on the right
                        HStack(spacing: 8) {
                            if let s = effectiveStart {
                                let end = s.addingTimeInterval(TimeInterval(goal))
                                ProgressView(timerInterval: s...end, countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                                    .progressViewStyle(.linear)
                                    .tint(color)
                                    .frame(maxWidth: .infinity)
                            } else {
                                ProgressView(value: min(Double(base), Double(goal)), total: Double(goal))
                                    .progressViewStyle(.linear)
                                    .tint(color)
                                    .frame(maxWidth: .infinity)
                            }
                            Button(intent: ToggleHabitTimerIntent(habitId: context.attributes.habitId, shouldRun: !isRunning)) {
                                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                    .font(.title3)
                                    .foregroundColor(color)
                                    .padding(6)
                            }
                            .buttonStyle(FlashCircleBackgroundStyle(color: color))
                        }
                        // Elapsed time under the bar
                        HStack(spacing: 8) {
                            displayNumericTime(base: base, goal: goal, effectiveStart: effectiveStart)
                                .font(.caption)
                                .monospacedDigit()
                                .numericTextTransition()
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.horizontal)
                }
                DynamicIslandExpandedRegion(.bottom) { }
            } compactLeading: {
                // Keep compactLeading minimal to free width for trailing time
                let color = Color(hex: context.attributes.colorHex)
                HStack(spacing: 8) {
                    Image(systemName: context.attributes.icon)
                        .foregroundColor(color)
                        .imageScale(.small)
                    Text(context.attributes.name)
                }
            } compactTrailing: {
                let color = Color(hex: context.attributes.colorHex)
                let base = max(0, context.state.baseElapsedSeconds)
                let start = context.state.sessionStartDate
                let goal = max(context.attributes.targetGoalSeconds, 1)
                let effectiveStart = start?.addingTimeInterval(TimeInterval(-base))
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.2), lineWidth: 3)
                    if let s = effectiveStart {
                        // Live, increasing fill as time progresses
                        let end = s.addingTimeInterval(TimeInterval(goal))
                        ProgressView(timerInterval: s...end, countsDown: false, label: {EmptyView()}, currentValueLabel: {EmptyView()})
                            .progressViewStyle(.circular)
                            .tint(color)
                            .labelsHidden()
                    } else {
                        // Paused: static snapshot of elapsed fraction
                        ProgressView(value: min(Double(base), Double(goal)), total: Double(goal))
                            .progressViewStyle(.circular)
                            .tint(color)
                            .labelsHidden()
                    }
                }
                .frame(width: 18, height: 18)
            } minimal: {
                Image(systemName: context.attributes.icon)
                    .foregroundColor(Color(hex: context.attributes.colorHex))
            }
        }
    }
}

// MARK: - Components
@available(iOS 16.1, *)
private struct LinearRemainingBar: View {
    let elapsed: Int
    let goal: Int
    let color: Color

    var body: some View {
        let clampedGoal = max(goal, 1)
        let elapsedClamped = min(max(elapsed, 0), clampedGoal)
        let frac = Double(elapsedClamped) / Double(clampedGoal)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.2))
                Capsule()
                    .fill(color)
                    .frame(width: max(0, geo.size.width * frac))
            }
        }
        .frame(height: 6)
    }
}

@available(iOS 16.1, *)
private struct PlayPauseGlyph: View {
    let isRunning: Bool
    let color: Color
    var body: some View {
        Image(systemName: isRunning ? "pause.fill" : "play.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(color)
            .accessibilityLabel(isRunning ? "Pause" : "Start")
    }
}

@available(iOS 16.1, *)
private struct PlayPauseControl: View {
    let habitId: String
    let isRunning: Bool
    let color: Color

    var body: some View {
        Button(intent: ToggleHabitTimerIntent(habitId: habitId, shouldRun: !isRunning)) {
            PlayPauseGlyph(isRunning: isRunning, color: color)
        }
        .buttonStyle(FlashCircleBackgroundStyle(color: color))
    }
}

@available(iOS 16.1, *)
private struct FlashCircleBackgroundStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(
                Circle()
                    .fill(color.opacity(configuration.isPressed ? 0.9 : 0.0))
            )
            .foregroundColor(configuration.isPressed ? .white : color)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}


@available(iOS 16.1, *)
private func displayNumericTime(base: Int, goal: Int, effectiveStart: Date?) -> Text {
    if let s = effectiveStart {
        // Running: show elapsed within the session window, updates live until goal
        let end = s.addingTimeInterval(TimeInterval(goal))
        return Text(timerInterval: s...end, countsDown: false)
    } else {
        // Paused: static snapshot of elapsed time
        return Text(elapsedString(base))
    }
}

// MARK: - Helpers
@available(iOS 16.1, *)
private extension View {
    @ViewBuilder
    func numericTextTransition() -> some View {
        if #available(iOS 17.0, *) {
            self.contentTransition(.numericText())
        } else {
            self
        }
    }
}

@available(iOS 16.1, *)
private func elapsedString(_ secs: Int) -> String {
    let h = secs / 3600
    let m = (secs % 3600) / 60
    let s = secs % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                 : String(format: "%d:%02d", m, s)
}

@available(iOS 16.1, *)
private func remainingString(_ secs: Int) -> String {
    let h = secs / 3600
    let m = (secs % 3600) / 60
    let s = secs % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}

@available(iOS 16.1, *)
private func shortRemaining(_ secs: Int) -> String {
    let m = max(0, secs) / 60
    return "\(m)m"
}

@available(iOS 16.1, *)
private func compactVerboseRemaining(_ secs: Int) -> String {
    let total = max(0, secs)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h >= 1 {
        return "\(h)h \(m)m"
    } else {
        return "\(m)m \(s)s"
    }
}

@available(iOS 16.1, *)
private func elapsedVerbose(_ secs: Int) -> String {
    let total = max(0, secs)
    if total < 60 {
        return "\(total)s"
    }
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h >= 1 {
        return "\(h)h \(m)m \(s)s"
    } else {
        return "\(m)m \(s)s"
    }
}

// MARK: - Color(hex:) helper for Widget target
@available(iOS 16.1, *)
private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 122, 255) // default iOS blue
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#if DEBUG
@available(iOS 16.1, *)
struct HabitTimerLiveActivity_Previews: PreviewProvider {
    static var previews: some View {
        let attributes = TimerAttributes(
            habitId: "demo",
            name: "Focus",
            icon: "timer",
            colorHex: "#007AFF",
            targetGoalSeconds: 4000
        )
        let content = TimerContentState(baseElapsedSeconds: 1300, sessionStartDate: Date(), isRunning: true, isFinished: false)
        return attributes.previewContext(content, viewKind: .content)
    }
}
#endif
