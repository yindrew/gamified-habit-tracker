//
//  ContentView.swift
//  gamified-habit-tracker
//
//  Created by Andrew Yin on 9/5/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAddHabit = false
    @State private var showCelebrationToast = false
    @State private var lastCelebrationDate: Date?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Habit.createdDate, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default)
    private var habits: FetchedResults<Habit>
    
    private var sortedHabits: [Habit] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return habits.sorted { habit1, habit2 in
            // Check if habits are scheduled for today
            let isScheduled1 = habit1.isScheduledToday
            let isScheduled2 = habit2.isScheduledToday
            
            // Prioritize scheduled habits
            if isScheduled1 != isScheduled2 {
                return isScheduled1 && !isScheduled2
            }
            
            // For scheduled habits, check completion status
            if isScheduled1 && isScheduled2 {
                let completions1 = habit1.completions?.filtered(using: NSPredicate(format: "completedDate >= %@ AND completedDate < %@", today as NSDate, tomorrow as NSDate)).count ?? 0
                let completions2 = habit2.completions?.filtered(using: NSPredicate(format: "completedDate >= %@ AND completedDate < %@", today as NSDate, tomorrow as NSDate)).count ?? 0
                
                let target1 = habit1.isScheduledToday ? habit1.targetFrequency : 0
                let target2 = habit2.isScheduledToday ? habit2.targetFrequency : 0
                let isCompleted1 = completions1 >= target1
                let isCompleted2 = completions2 >= target2
                
                // Incomplete scheduled habits first
                if isCompleted1 != isCompleted2 {
                    return !isCompleted1 && isCompleted2
                }
            }
            
            // Within same group, sort by creation date
            return habit1.createdDate ?? Date() < habit2.createdDate ?? Date()
        }
    }
    
    private var scheduledHabitsForToday: [Habit] {
        return habits.filter { $0.isScheduledToday }
    }
    
    private var completedHabitsForToday: [Habit] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return scheduledHabitsForToday.filter { habit in
            let completions = habit.completions?.filtered(using: NSPredicate(format: "completedDate >= %@ AND completedDate < %@", today as NSDate, tomorrow as NSDate)).count ?? 0
            let target = habit.isScheduledToday ? habit.targetFrequency : 0
            return completions >= target && target > 0
        }
    }
    
    private var allHabitsCompletedToday: Bool {
        let scheduledCount = scheduledHabitsForToday.count
        let completedCount = completedHabitsForToday.count
        return scheduledCount > 0 && scheduledCount == completedCount
    }

    var body: some View {
        NavigationView {
            ZStack {
                if habits.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "target")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Habits Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Tap the + button to create your first habit and start building better routines!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(sortedHabits, id: \.self) { habit in
                            NavigationLink(destination: HabitDetailView(habit: habit)) {
                                HabitRowView(habit: habit)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // Celebration toast overlay
                if showCelebrationToast {
                    CelebrationToastView(
                        completedHabits: completedHabitsForToday,
                        isPresented: $showCelebrationToast
                    )
                    .zIndex(1000)
                }
            }
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("My Habits")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            showingAddHabit = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                HabitFormView(mode: .add)
            }
            .onChange(of: allHabitsCompletedToday) { completed in
                checkForCelebration()
            }
            .onAppear {
                checkForCelebration()
            }
        }
    }
    
    private func checkForCelebration() {
        guard allHabitsCompletedToday else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Check if we've already shown celebration today
        if let lastCelebration = lastCelebrationDate,
           calendar.isDate(lastCelebration, inSameDayAs: today) {
            return
        }
        
        // Show celebration and mark date
        lastCelebrationDate = today
        showCelebrationToast = true
    }

}

struct HabitRowView: View {
    @ObservedObject var habit: Habit
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingCompletionAnimation = false
    @State private var isHolding = false
    @State private var holdProgress: Double = 0.0
    @State private var holdTimer: Timer?
    @State private var isInCooldown = false
    @State private var showingCopingPlanAlert = false
    
    private var isCompletedToday: Bool {
        guard let lastCompleted = habit.lastCompletedDate else { return false }
        return Calendar.current.isDateInToday(lastCompleted)
    }
    
    private var completionsToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let todayCompletions = habit.completions?.filtered(using: NSPredicate(format: "completedDate >= %@ AND completedDate < %@", today as NSDate, tomorrow as NSDate))
        return todayCompletions?.count ?? 0
    }
    
    private var progressPercentage: Double {
        let target = habit.isScheduledToday ? habit.targetFrequency : 0
        guard target > 0 else { return completionsToday > 0 ? 1.0 : 0.0 }
        return min(Double(completionsToday) / Double(target), 1.0)
    }
    
    var body: some View {
        HStack(spacing: 15) {
            // Habit Icon
            ZStack {
                Circle()
                    .fill(Color(hex: habit.colorHex ?? "#007AFF").opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: habit.icon ?? "star")
                    .font(.title2)
                    .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(habit.name ?? "Unnamed Habit")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Streak indicator
                    if habit.currentStreak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("\(habit.currentStreak)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                
                // Schedule indicator
                if habit.schedule != .daily {
                    HStack(spacing: 2) {
                        if !habit.isScheduledToday {
                            Text("• Not scheduled today")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                // Progress bar
                HStack(spacing: 8) {
                    ProgressView(value: progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: habit.colorHex ?? "#007AFF")))
                        .frame(height: 4)
                    
                    Text("\(completionsToday)/\(habit.isScheduledToday ? habit.targetFrequency : 0)")
                        .font(.caption2)
                        .foregroundColor(completionsToday >= (habit.isScheduledToday ? habit.targetFrequency : 0) ? Color(hex: habit.colorHex ?? "#007AFF") : .secondary)
                        .fontWeight(completionsToday >= (habit.isScheduledToday ? habit.targetFrequency : 0) ? .bold : .medium)
                }
            }
            
            // Action buttons
            HStack(spacing: 8) {
                // Coping plan button (if available)
                if habit.canUseCopingPlanToday {
                    Button(action: {
                        showingCopingPlanAlert = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.pink.opacity(0.1))
                                .frame(width: 30, height: 30)
                            
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.pink)
                        }
                    }
                }
                
                // Complete button with press-and-hold ring animation (only if scheduled today or daily)
                ZStack {
                    // Background ring that fills up during hold
                    Circle()
                        .stroke(Color(hex: habit.colorHex ?? "#007AFF").opacity(0.2), lineWidth: 3)
                        .frame(width: 36, height: 36)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: holdProgress)
                        .stroke(
                            Color(hex: habit.colorHex ?? "#007AFF").opacity(0.6),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: holdProgress)
                    
                    // Main button
                    Circle()
                        .fill(completionsToday >= (habit.isScheduledToday ? habit.targetFrequency : 0) ? Color(hex: habit.colorHex ?? "#007AFF") : Color(hex: habit.colorHex ?? "#007AFF").opacity(isHolding ? 0.3 : 0.1))
                        .frame(width: 30, height: 30)
                        .scaleEffect(isHolding ? 0.95 : (showingCompletionAnimation ? 1.2 : 1.0))
                        .opacity(isInCooldown ? 0.5 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHolding)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showingCompletionAnimation)
                        .animation(.easeInOut(duration: 0.2), value: isInCooldown)
                    
                    Image(systemName: completionsToday >= (habit.isScheduledToday ? habit.targetFrequency : 0) ? "checkmark" : "plus")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(completionsToday >= (habit.isScheduledToday ? habit.targetFrequency : 0) ? .white : Color(hex: habit.colorHex ?? "#007AFF"))
                        .scaleEffect(isHolding ? 0.9 : 1.0)
                        .opacity(isInCooldown ? 0.5 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHolding)
                        .animation(.easeInOut(duration: 0.2), value: isInCooldown)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isHolding && !isInCooldown {
                                startHolding()
                            }
                        }
                        .onEnded { _ in
                            endHolding()
                        }
                )

            }
        }
        .padding(.vertical, 4)
        .alert("Use Coping Plan", isPresented: $showingCopingPlanAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Complete Coping Plan") {
                completeCopingPlan()
            }
        } message: {
            Text((habit.copingPlan?.isEmpty == false) ? habit.copingPlan! : "Complete your alternative plan to maintain your streak.")
        }
    }
    
    private func startHolding() {
        guard !isHolding && !isInCooldown else { return }
        
        isHolding = true
        holdProgress = 0.0
        
        // Light haptic feedback on start
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Start progress timer (1.5 second hold duration)
        let totalDuration: Double = 0.75
        let updateInterval: Double = 0.05
        let progressIncrement = updateInterval / totalDuration
        
        holdTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            holdProgress += progressIncrement
            
            if holdProgress >= 1.0 {
                timer.invalidate()
                completeHabit()
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
        
        // End cooldown after 0.2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isInCooldown = false
        }
    }
    
    private func completeHabit() {
        // Strong haptic feedback on completion
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring()) {
            showingCompletionAnimation = true
            
            // Create completion record
            let completion = HabitCompletion(context: viewContext)
            completion.id = UUID()
            completion.completedDate = Date()
            completion.habit = habit
            
            // Update habit statistics
            habit.totalCompletions += 1
            habit.lastCompletedDate = Date()
            
            // Update streak
            updateStreak()
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
            
            // Reset animation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingCompletionAnimation = false
                holdProgress = 0.0
            }
        }
    }
    
    private func completeCopingPlan() {
        withAnimation(.spring()) {
            showingCompletionAnimation = true
            
            // Complete the coping plan
            habit.completeCopingPlan()
            
            // Light haptic feedback for coping plan
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
            
            // Reset animation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingCompletionAnimation = false
            }
        }
    }
    
    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        guard let lastCompleted = habit.lastCompletedDate else {
            habit.currentStreak = 1
            habit.longestStreak = max(habit.longestStreak, 1)
            return
        }
        
        let lastCompletedDay = calendar.startOfDay(for: lastCompleted)
        let daysBetween = calendar.dateComponents([.day], from: lastCompletedDay, to: today).day ?? 0
        
        if daysBetween == 0 {
            // Completed today already, streak continues
            return
        } else if daysBetween == 1 {
            // Completed yesterday, increment streak
            habit.currentStreak += 1
        } else {
            // Gap in completions, reset streak
            habit.currentStreak = 1
        }
        
        habit.longestStreak = max(habit.longestStreak, habit.currentStreak)
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
