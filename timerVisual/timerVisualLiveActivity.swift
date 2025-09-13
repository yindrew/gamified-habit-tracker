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

@available(iOS 16.1, *)
struct HabitTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            // Lock Screen / Notification Center
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(context.attributes.colorHex).opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: context.attributes.icon)
                        .foregroundColor(Color(context.attributes.colorHex))
                        .font(.system(size: 14, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(elapsedString(context.state.elapsedSeconds))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .activityBackgroundTint(Color(.systemBackground).opacity(0.9))
            .activitySystemActionForegroundColor(Color(context.attributes.colorHex))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.icon)
                        .foregroundColor(Color(context.attributes.colorHex))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.name)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(elapsedString(context.state.elapsedSeconds))
                        .monospacedDigit()
                }
            } compactLeading: {
                Image(systemName: context.attributes.icon)
                    .foregroundColor(Color(context.attributes.colorHex))
            } compactTrailing: {
                Text(shortElapsed(context.state.elapsedSeconds))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: context.attributes.icon)
                    .foregroundColor(Color(context.attributes.colorHex))
            }
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
private func shortElapsed(_ secs: Int) -> String { "\(secs / 60)m" }

#if DEBUG
@available(iOS 16.1, *)
struct HabitTimerLiveActivity_Previews: PreviewProvider {
    static var previews: some View {
        let attributes = TimerAttributes(
            habitId: "demo",
            name: "Focus",
            icon: "timer",
            colorHex: "#007AFF",
            targetGoalSeconds: 1800
        )
        let content = TimerContentState(elapsedSeconds: 125, isRunning: true, isFinished: false)
        return attributes.previewContext(content, viewKind: .content)
    }
}
#endif
