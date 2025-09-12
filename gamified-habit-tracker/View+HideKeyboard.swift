//
//  View+HideKeyboard.swift
//  gamified-habit-tracker
//
//  Small helper to dismiss the keyboard from SwiftUI by resigning first responder.
//

import SwiftUI
import UIKit

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

