//
//  FocusModeView.swift
//  gamified-habit-tracker
//
//  Created by Codex on 9/9/25.
//

import SwiftUI

struct FocusModeView: View {
    @ObservedObject var habit: Habit
    @Binding var isPresented: Bool
    @Binding var elapsedTime: TimeInterval
    let isRunning: Bool
    let onToggleTimer: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("focusTapHintHidden") private var focusTapHintHidden: Bool = false

    private var goalSeconds: TimeInterval {
        habit.goalValue * 60.0
    }

    private var completedSeconds: TimeInterval { elapsedTime }

    private var remaining: TimeInterval { max(0, goalSeconds - completedSeconds) }

    private var progress: Double {
        guard goalSeconds > 0 else { return 0 }
        return min(completedSeconds / goalSeconds, 1.0)
    }

    private var elapsedText: String {
        let total = Int(elapsedTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white).ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // Text(habit.name ?? "Focus")
                        //     .font(.title2).fontWeight(.semibold)
                    }
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()

                // Big circular progress + control (tap anywhere on or within the ring)
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 14)
                        .frame(width: 220, height: 220)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color(hex: habit.colorHex ?? "#007AFF"), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.25), value: progress)

                    VStack(spacing: 8) {
                        // Show stopwatch-style elapsed time that keeps incrementing and does not reset on pause
                        Text(elapsedText)
                            .font(.system(size: 36, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                        // Optional subtle time-left hint until goal is reached
                        Text(remaining > 0 ? timeLeftString(remaining) : goalMetOverrunText())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 220, height: 220)
                .contentShape(Circle())
                .onTapGesture { onToggleTimer() }

                if !focusTapHintHidden {
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Button(action: { focusTapHintHidden = true }) {
                                Image(systemName: "square")
                                    .foregroundColor(.secondary)
                            }
                            Text("Tap anywhere in or on the ring to play/pause")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    private func timeLeftString(_ remaining: TimeInterval) -> String {
        let hrs = Int(remaining) / 3600
        let mins = (Int(remaining) % 3600) / 60
        let secs = Int(remaining) % 60
        if remaining >= 3600 {
            return String(format: "%dh %dm %ds left", hrs, mins, secs)
        } else if remaining >= 60 {
            return String(format: "%dm %ds left", mins, secs)
        } else {
            return String(format: "%ds left", secs)
        }
    }

    private func goalMetOverrunText() -> String {
        let overrun = max(0, completedSeconds - goalSeconds)
        let minutes = Int(overrun / 60.0)
        return minutes > 0 ? "Goal met +\(minutes)m" : "Goal met"
    }
}

#Preview {
    FocusModeView(
        habit: Habit(),
        isPresented: .constant(true),
        elapsedTime: .constant(0),
        isRunning: true,
        onToggleTimer: {}
    )
}
