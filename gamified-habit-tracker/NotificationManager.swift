//
//  NotificationManager.swift
//  gamified-habit-tracker
//
//  Created by Codex on 9/11/25.
//

import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private func identifierPrefix(for habit: Habit) -> String {
        let idStr = habit.id?.uuidString ?? "unknown"
        return "habit-\(idStr)-"
    }

    private func removeExistingNotifications(for habit: Habit, completion: (() -> Void)? = nil) {
        let prefix = identifierPrefix(for: habit)
        let center = UNUserNotificationCenter.current()

        center.getPendingNotificationRequests { requests in
            let ids = requests.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            completion?()
        }
    }

    func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
        let center = UNUserNotificationCenter.current()

        func finish(_ granted: Bool) {
            if Thread.isMainThread {
                completion?(granted)
            } else {
                DispatchQueue.main.async { completion?(granted) }
            }
        }

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                finish(true)
            case .denied:
                finish(false)
            case .notDetermined:
                // Requesting authorization may present a system alert; do it on main thread
                DispatchQueue.main.async {
                    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                        finish(granted)
                    }
                }
            @unknown default:
                finish(false)
            }
        }
    }

    func scheduleNotifications(for habit: Habit) {
        guard habit.notificationsEnabled, let notifDate = habit.notificationTime else {
            // If disabled or no time, ensure existing notifications are removed
            removeExistingNotifications(for: habit)
            return
        }

        requestAuthorizationIfNeeded { [weak self] granted in
            guard let self = self, granted else { return }

            // Clear previous notifications for this habit
            self.removeExistingNotifications(for: habit) {
                let center = UNUserNotificationCenter.current()

                let calendar = Calendar.current
                let comps = calendar.dateComponents([.hour, .minute], from: notifDate)

                // Build requests by schedule type
                var requests: [UNNotificationRequest] = []

                let content = UNMutableNotificationContent()
                content.title = habit.name ?? "Habit Reminder"
                content.body = "It's time to work on your habit."
                content.sound = .default

                func makeRequest(id: String, dateComponents: DateComponents) -> UNNotificationRequest {
                    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                    return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                }

                let baseId = self.identifierPrefix(for: habit)

                switch habit.schedule {
                case .daily:
                    var dc = DateComponents()
                    dc.hour = comps.hour
                    dc.minute = comps.minute
                    requests.append(makeRequest(id: baseId + "daily", dateComponents: dc))

                case .weekdaysOnly:
                    for weekday in 2...6 { // Mon-Fri (2=Mon, 6=Fri)
                        var dc = DateComponents()
                        dc.weekday = weekday
                        dc.hour = comps.hour
                        dc.minute = comps.minute
                        requests.append(makeRequest(id: baseId + "weekday-\(weekday)", dateComponents: dc))
                    }

                case .weekendsOnly:
                    for weekday in [1, 7] { // Sun & Sat
                        var dc = DateComponents()
                        dc.weekday = weekday
                        dc.hour = comps.hour
                        dc.minute = comps.minute
                        requests.append(makeRequest(id: baseId + "weekday-\(weekday)", dateComponents: dc))
                    }

                case .weekly:
                    for weekday in habit.weeklyScheduleDays { // Uses 1=Sun..7=Sat
                        var dc = DateComponents()
                        dc.weekday = weekday
                        dc.hour = comps.hour
                        dc.minute = comps.minute
                        requests.append(makeRequest(id: baseId + "weekday-\(weekday)", dateComponents: dc))
                    }

                case .monthly:
                    for day in habit.monthlyScheduleDays { // 1..31
                        var dc = DateComponents()
                        dc.day = day
                        dc.hour = comps.hour
                        dc.minute = comps.minute
                        requests.append(makeRequest(id: baseId + "monthday-\(day)", dateComponents: dc))
                    }
                }

                // Add all requests
                for req in requests {
                    center.add(req, withCompletionHandler: nil)
                }
            }
        }
    }

    func cancelNotifications(for habit: Habit) {
        removeExistingNotifications(for: habit)
    }
}
