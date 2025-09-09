//
//  RoutineStepView.swift
//  gamified-habit-tracker
//
//  Created by Andrew Yin on 9/9/25.
//


import SwiftUI
import CoreData

struct RoutineStepView: View {
    let step: String
    let index: Int
    let isCompleted: Bool
    let habitColor: Color
    let onComplete: () -> Void
    
    @State private var isHolding = false
    @State private var holdProgress: Double = 0.0
    @State private var holdTimer: Timer?
    @State private var isInCooldown = false
    @State private var showingCompletionAnimation = false
    
    private var buttonIcon: String {
        return isCompleted ? "checkmark" : "plus"
    }
    
    private var buttonBackgroundColor: Color {
        if isCompleted {
            return habitColor
        } else {
            return habitColor.opacity(isHolding ? 0.3 : 0.1)
        }
    }
    
    private var buttonIconColor: Color {
        return isCompleted ? .white : habitColor
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Step number
            Text("\(index + 1).")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)
            
            // Step description
            Text(step)
                .font(.caption2)
                .foregroundColor(isCompleted ? habitColor : .primary)
                .strikethrough(isCompleted)
                .lineLimit(1)
            
            Spacer()
            
            // Press-and-hold completion ring
            ZStack {
                // Background ring that fills up during hold
                Circle()
                    .stroke(habitColor.opacity(0.2), lineWidth: 2)
                    .frame(width: 28, height: 28)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(
                        habitColor.opacity(0.6),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: holdProgress)
                
                // Main button
                Circle()
                    .fill(buttonBackgroundColor)
                    .frame(width: 24, height: 24)
                    .scaleEffect(isHolding ? 0.95 : (showingCompletionAnimation ? 1.2 : 1.0))
                    .opacity(isInCooldown ? 0.5 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHolding)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showingCompletionAnimation)
                    .animation(.easeInOut(duration: 0.2), value: isInCooldown)
                
                Image(systemName: buttonIcon)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(buttonIconColor)
                    .scaleEffect(isHolding ? 0.9 : 1.0)
                    .opacity(isInCooldown ? 0.5 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHolding)
                    .animation(.easeInOut(duration: 0.2), value: isInCooldown)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isHolding && !isInCooldown && !isCompleted {
                            startHolding()
                        }
                    }
                    .onEnded { _ in
                        endHolding()
                    }
            )
        }
    }
    
    private func startHolding() {
        guard !isHolding && !isInCooldown && !isCompleted else { return }
        
        isHolding = true
        holdProgress = 0.0
        
        // Light haptic feedback on start
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Start progress timer (0.75 second hold duration)
        let totalDuration: Double = 0.75
        let updateInterval: Double = 0.05
        let progressIncrement = updateInterval / totalDuration
        
        holdTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            holdProgress += progressIncrement
            
            if holdProgress >= 1.0 {
                timer.invalidate()
                completeStep()
                endHolding(completed: true)
                startCooldown()
            }
        }
    }
    
    private func endHolding(completed: Bool = false) {
        holdTimer?.invalidate()
        holdTimer = nil
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isHolding = false
            if !completed {
                holdProgress = 0.0
            }
        }
        
        // Reset progress after animation if not completed
        if !completed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                holdProgress = 0.0
            }
        }
    }
    
    private func startCooldown() {
        isInCooldown = true
        
        // Reset progress after completion animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            holdProgress = 0.0
        }
        
        // End cooldown after 0.8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isInCooldown = false
        }
    }
    
    private func completeStep() {
        // Medium haptic feedback on completion
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring()) {
            showingCompletionAnimation = true
            
            // Call the completion handler
            onComplete()
            
            // Reset animation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingCompletionAnimation = false
                holdProgress = 0.0
            }
        }
    }
}
