import Foundation
import SwiftUI
import UserNotifications

enum AlertKind: String {
    /// Counts down a set length, starting when the user sets it.
    case timer
    /// Rings at a clock time, such as 3:30 PM.
    case alarm
}

// MARK: - What a block remembers about its alert

extension Block {
    var alertKind: AlertKind? {
        alertKindRaw.flatMap(AlertKind.init(rawValue:))
    }

    /// Start a countdown from now.
    func setTimer(seconds: TimeInterval, at now: Date = .now) {
        alertKindRaw = AlertKind.timer.rawValue
        alertSetAt = now
        timerSeconds = seconds
        alertTargetAt = now.addingTimeInterval(seconds)
        alertDueAt = alertTargetAt
        snoozeCount = 0
        snoozedSeconds = 0
        AlertScheduler.schedule(self)
    }

    /// Ring at a clock time.
    func setAlarm(at target: Date, now: Date = .now) {
        alertKindRaw = AlertKind.alarm.rawValue
        alertSetAt = now
        timerSeconds = nil
        alertTargetAt = target
        alertDueAt = target
        snoozeCount = 0
        snoozedSeconds = 0
        AlertScheduler.schedule(self)
    }

    /// Delay a ringing alert. Counts and totals are kept for the record.
    func snooze(by seconds: TimeInterval, at now: Date = .now) {
        snoozeCount += 1
        snoozedSeconds += seconds
        alertDueAt = now.addingTimeInterval(seconds)
        AlertScheduler.schedule(self)
    }

    /// Stop ringing and do not ring again. The record stays.
    func dismissAlert() {
        alertDueAt = nil
        AlertScheduler.cancel(self)
    }

    /// Remove the alert completely, as if it was never set.
    func clearAlert() {
        AlertScheduler.cancel(self)
        alertKindRaw = nil
        alertSetAt = nil
        timerSeconds = nil
        alertTargetAt = nil
        alertDueAt = nil
        snoozeCount = 0
        snoozedSeconds = 0
    }

    /// End the block. Any alert that has not rung yet is cancelled.
    func close(at now: Date) {
        endedAt = now
        alertDueAt = nil
        AlertScheduler.cancel(self)
    }

    func isRinging(at now: Date) -> Bool {
        guard endedAt == nil, let due = alertDueAt else { return false }
        return due <= now
    }

    /// One line for the Track screen, e.g. "Timer 25:00 · 12:03 left · snoozed 1× (05:00)"
    func alertSummary(now: Date) -> String {
        guard let kind = alertKind else { return "" }
        var parts: [String] = []
        switch kind {
        case .timer:
            parts.append("Timer \(formatDuration(timerSeconds ?? 0))")
        case .alarm:
            let time = (alertTargetAt ?? now).formatted(date: .omitted, time: .shortened)
            parts.append("Alarm \(time)")
        }
        if let due = alertDueAt {
            let left = due.timeIntervalSince(now)
            parts.append(left > 0 ? "\(formatDuration(left)) left" : "ringing")
        } else if endedAt == nil {
            parts.append("dismissed")
        }
        if snoozeCount > 0 {
            parts.append("snoozed \(snoozeCount)× (\(formatDuration(snoozedSeconds)))")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Notifications

/// Schedules a local notification so the alert is heard when the app is not open.
enum AlertScheduler {
    static func schedule(_ block: Block) {
        cancel(block)
        guard let due = block.alertDueAt else { return }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        let content = UNMutableNotificationContent()
        content.title = block.alertKind == .alarm ? "Alarm" : "Timer done"
        content.body = (block.tags?.isEmpty ?? true) ? "Your block is waiting." : block.title
        content.sound = .default

        let seconds = max(1, due.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: block.uid.uuidString,
                                         content: content,
                                         trigger: trigger))
    }

    static func cancel(_ block: Block) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [block.uid.uuidString])
    }
}

/// Lets the notification show and play its sound while the app is open.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

// MARK: - Views

/// Shown when a timer or alarm is due. The user can snooze or dismiss it.
struct RingingBanner: View {
    @Bindable var block: Block

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(block.alertKind == .alarm ? "Alarm" : "Timer done")
                    .font(.headline)
                Text(block.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu("Snooze") {
                ForEach([1, 5, 10, 15], id: \.self) { minutes in
                    Button("\(minutes) min") { block.snooze(by: Double(minutes) * 60) }
                }
            }
            .buttonStyle(.bordered)
            Button("Dismiss") { block.dismissAlert() }
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(Color.yellow.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Set, see or clear the timer or alarm of one block.
struct AlertControl: View {
    @Bindable var block: Block
    let now: Date

    @State private var expanded = false
    @State private var mode: AlertKind = .timer
    @State private var minutes = 25
    @State private var alarmTime = Date()

    var body: some View {
        if block.alertKind != nil {
            HStack {
                Label(block.alertSummary(now: now), systemImage: block.alertKind == .alarm ? "alarm" : "timer")
                    .font(.footnote)
                Spacer()
                Button("Clear", role: .destructive) { block.clearAlert() }
                    .buttonStyle(.borderless)
                    .font(.footnote)
            }
        } else if expanded {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Type", selection: $mode) {
                    Text("Timer").tag(AlertKind.timer)
                    Text("Alarm").tag(AlertKind.alarm)
                }
                .pickerStyle(.segmented)

                if mode == .timer {
                    HStack {
                        ForEach([5, 15, 25, 45], id: \.self) { preset in
                            Button("\(preset)m") { minutes = preset }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                        Stepper("\(minutes) min", value: $minutes, in: 1...600)
                    }
                } else {
                    DatePicker("Rings at", selection: $alarmTime, displayedComponents: .hourAndMinute)
                }

                HStack {
                    Button("Set", action: apply)
                        .buttonStyle(.borderedProminent)
                    Button("Cancel") { expanded = false }
                        .buttonStyle(.bordered)
                }
            }
        } else {
            Button { expanded = true } label: {
                Label("Timer or alarm", systemImage: "bell")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func apply() {
        switch mode {
        case .timer:
            block.setTimer(seconds: Double(minutes) * 60)
        case .alarm:
            // Next time the clock shows the chosen hour and minute.
            let parts = Calendar.current.dateComponents([.hour, .minute], from: alarmTime)
            if let target = Calendar.current.nextDate(after: .now, matching: parts,
                                                      matchingPolicy: .nextTime) {
                block.setAlarm(at: target)
            }
        }
        expanded = false
    }
}
