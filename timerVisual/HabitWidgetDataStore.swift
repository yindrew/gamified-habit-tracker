//
//  HabitWidgetDataStore.swift
//  timerVisual
//
//  Reads habit snapshots shared by the main app via UserDefaults.
//

import Foundation
import SharedTimerModels

struct HabitWidgetDataStore {
    private var defaults: UserDefaults {
        if let shared = UserDefaults(suiteName: HabitWidgetStoreConstants.suiteName) {
            return shared
        }
        #if DEBUG
        print("[HabitWidgetDataStore] App Group not configured; using standard UserDefaults. Widget data may be stale.")
        #endif
        return .standard
    }

    func loadSnapshots() -> [HabitWidgetSnapshot] {
        guard let data = defaults.data(forKey: HabitWidgetStoreConstants.snapshotsKey) else {
            return [HabitWidgetSnapshot.placeholder]
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshots = try decoder.decode([HabitWidgetSnapshot].self, from: data)
            return snapshots.isEmpty ? [HabitWidgetSnapshot.placeholder] : snapshots
        } catch {
            #if DEBUG
            print("[HabitWidgetDataStore] Failed to decode snapshots: \(error)")
            #endif
            return [HabitWidgetSnapshot.placeholder]
        }
    }

    func snapshot(for habitId: String) -> HabitWidgetSnapshot? {
        loadSnapshots().first { $0.id == habitId }
    }
}
