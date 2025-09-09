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

    private var goalSeconds: TimeInterval {
        habit.goalValue * 60.0
    }

    private var completedSeconds: TimeInterval {
        (habit.timerMinutesToday * 60.0) + elapsedTime
    }

    private var remaining: TimeInterval {
        max(0, goalSeconds - completedSeconds)
    }

    private var progress: Double {
        guard goalSeconds > 0 else { return 0 }
        return min(completedSeconds / goalSeconds, 1.0)
    }

    private var remainingText: String {
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        if remaining >= 3600 {
            return String(format: "%dh %dm %ds left", hours, minutes, seconds)
        } else if remaining >= 60 {
            return String(format: "%dm %ds left", minutes, seconds)
        } else {
            return String(format: "%ds left", seconds)
        }
    }

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white).ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.name ?? "Focus")
                            .font(.title2).fontWeight(.semibold)
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

                // Big circular progress + control
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
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.largeTitle)
                            .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
                        Text(remainingText)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                .onTapGesture { onToggleTimer() }

                Spacer()
            }
            .padding()
        }
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
