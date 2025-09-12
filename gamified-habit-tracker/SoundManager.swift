//
//  SoundManager.swift
//  gamified-habit-tracker
//
//  Lightweight system sound helper for small UI cues.
//

import Foundation
import AudioToolbox

enum SoundManager {
    /// Plays a small ring sound to indicate the timer completed.
    static func playTimerComplete() {
        // 1057 is a light 'Tink' sound; adjust if desired
        let soundId: SystemSoundID = 1057
        AudioServicesPlaySystemSound(soundId)
    }
}

