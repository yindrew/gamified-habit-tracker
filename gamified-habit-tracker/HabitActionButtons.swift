//
//  HabitActionButtons.swift
//  gamified-habit-tracker
//
//  Extracted from HabitRowView for clarity
//

import SwiftUI

struct HabitActionButtons: View {
    // Visual config
    var ringColor: Color
    var showExpand: Bool
    var mainFillColor: Color
    var mainIcon: String
    var mainIconColor: Color

    // Actions
    var onMainHoldCompleted: () -> Void
    var onExpandHoldCompleted: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if showExpand {
                PressHoldRingButton(
                    ringColor: ringColor,
                    fillColor: ringColor.opacity(0.1),
                    icon: "arrow.up.left.and.arrow.down.right",
                    iconColor: ringColor,
                    onHoldCompleted: { onExpandHoldCompleted() }
                )
            }
            PressHoldRingButton(
                ringColor: ringColor,
                fillColor: mainFillColor,
                icon: mainIcon,
                iconColor: mainIconColor,
                onHoldCompleted: { onMainHoldCompleted() }
            )
        }
    }
}
