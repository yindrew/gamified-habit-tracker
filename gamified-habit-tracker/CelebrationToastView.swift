//
//  CelebrationToastView.swift
//  gamified-habit-tracker
//
//  Created by Andrew Yin on 9/5/25.
//

import SwiftUI

struct CelebrationToastView: View {
    let completedHabits: [Habit]
    @State private var isVisible = false
    @State private var progressValue: Double = 0.0
    @State private var showHabitIcons = false
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Full screen background
            Color.black.opacity(isVisible ? 0.8 : 0.0)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Large circular progress wheel with habit icons
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 6)
                        .frame(width: 200, height: 200)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: progressValue)
                        .stroke(
                            LinearGradient(
                                colors: [.green, .blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.2), value: progressValue)
                    
                    // Habit icons arranged around the circle
                    ForEach(Array(completedHabits.enumerated()), id: \.element) { index, habit in
                        let angle = (Double(index) / Double(completedHabits.count)) * 360
                        let radius: Double = 110
                        
                        ZStack {
                            Circle()
                                .fill(Color(hex: habit.colorHex ?? "#007AFF").opacity(showHabitIcons ? 0.3 : 0.0))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: habit.icon ?? "star")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
                                .opacity(showHabitIcons ? 1.0 : 0.0)
                                .scaleEffect(showHabitIcons ? 1.0 : 0.3)
                        }
                        .offset(
                            x: cos(angle * .pi / 180) * radius,
                            y: sin(angle * .pi / 180) * radius
                        )
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                            .delay(Double(index) * 0.1),
                            value: showHabitIcons
                        )
                    }
                    
                    // Center checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.green)
                        .opacity(progressValue >= 1.0 ? 1.0 : 0.0)
                        .scaleEffect(progressValue >= 1.0 ? 1.0 : 0.5)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(1.0), value: progressValue)
                }
                
                VStack(spacing: 8) {
                    Text("Today's goals completed!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isVisible)
        }
        .onAppear {
            startCelebrationAnimation()
        }
        .onTapGesture {
            dismissToast()
        }
    }
    
    private func startCelebrationAnimation() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Show toast
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isVisible = true
        }
        
        // Start progress animation after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            progressValue = 1.0
        }
        
        // Show habit icons after progress starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showHabitIcons = true
        }
        
        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            dismissToast()
        }
    }
    
    private func dismissToast() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isVisible = false
        }
        
        // Remove from parent after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isPresented = false
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    
    // Create sample habits for preview
    let sampleHabits: [Habit] = []
    
    return ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        if isPresented {
            CelebrationToastView(
                completedHabits: sampleHabits,
                isPresented: $isPresented
            )
        }
    }
}
