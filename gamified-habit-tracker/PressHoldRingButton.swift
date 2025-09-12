//
//  RingButton.swift
//  gamified-habit-tracker
//
//  Created by Andrew Yin on 9/9/25.
//

import SwiftUI

struct PressHoldRingButton: View {
    // Visuals
    var ringColor: Color
    var fillColor: Color
    var icon: String
    var iconColor: Color

    // Behavior
    var holdDuration: Double = 0.75
    var cooldownDuration: Double = 0.8
    var onHoldCompleted: () -> Void

    @State private var isHolding = false
    @State private var holdProgress: CGFloat = 0
    @State private var isInCooldown = false
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.2), lineWidth: 3)
                .frame(width: 36, height: 36)

            Circle()
                .trim(from: 0, to: holdProgress)
                .stroke(ringColor.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 36, height: 36)
                .animation(.linear(duration: 0.1), value: holdProgress)

            Circle()
                .fill(fillColor.opacity(isHolding ? 0.3 : 1.0))
                .frame(width: 30, height: 30)
                .scaleEffect(isHolding ? 0.95 : 1.0)
                .opacity(isInCooldown ? 0.5 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHolding)
                .animation(.easeInOut(duration: 0.2), value: isInCooldown)

            Image(systemName: icon)
                .font(.caption).fontWeight(.bold)
                .foregroundColor(iconColor)
                .opacity(isInCooldown ? 0.5 : 1.0)
        }
        .contentShape(Rectangle()) 
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startHoldIfNeeded() }
                .onEnded { _ in endHold() }
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Press and hold"))
    }

    private func startHoldIfNeeded() {
        guard !isHolding, !isInCooldown else { return }
        isHolding = true
        holdProgress = 0

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let tick: Double = 0.05
        let increment = tick / holdDuration

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: tick, repeats: true) { t in
            holdProgress += increment
            if holdProgress >= 1.0 {
                t.invalidate()
                onHoldCompleted()
                finishHold(completed: true)
            }
        }
    }

    private func endHold() {
        guard isHolding else { return }
        finishHold(completed: false)
    }

    private func finishHold(completed: Bool) {
        timer?.invalidate()
        timer = nil

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isHolding = false
            if !completed { holdProgress = 0 }
        }

        if completed {
            isInCooldown = true
            DispatchQueue.main.asyncAfter(deadline: .now() + cooldownDuration) {
                isInCooldown = false
                holdProgress = 0
            }
        }
    }
}
