import Foundation
import SwiftUI
import SwiftData
import AlarmKit

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
        BlockAlarms.schedule(self)
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
        BlockAlarms.schedule(self)
    }

    /// Delay a ringing alert. Counts and totals are kept for the record.
    func snooze(by seconds: TimeInterval, at now: Date = .now) {
        snoozeCount += 1
        snoozedSeconds += seconds
        alertDueAt = now.addingTimeInterval(seconds)
        BlockAlarms.schedule(self)
    }

    /// Stop ringing and do not ring again. The record stays.
    func dismissAlert() {
        alertDueAt = nil
        BlockAlarms.cancel(self)
    }

    /// Remove the alert completely, as if it was never set.
    func clearAlert() {
        BlockAlarms.cancel(self)
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
        BlockAlarms.cancel(self)
    }

    func isRinging(at now: Date) -> Bool {
        guard endedAt == nil, let due = alertDueAt else { return false }
        return due <= now
    }

    /// One line for the Track screen, e.g. "Timer 25:00 · 12:03 left · snoozed 1× (5:00)".
    /// The "left" part is a countdown drawn by the system, so it ticks
    /// without the app redrawing.
    func alertSummary(now: Date) -> Text {
        guard let kind = alertKind else { return Text("") }
        var text: Text
        switch kind {
        case .timer:
            text = Text("Timer \(formatDuration(timerSeconds ?? 0))")
        case .alarm:
            let time = (alertTargetAt ?? now).formatted(date: .omitted, time: .shortened)
            text = Text("Alarm \(time)")
        }
        if let due = alertDueAt {
            if due > now {
                let countdown = Text(timerInterval: now...due, countsDown: true)
                text = Text("\(text) · \(countdown) left")
            } else {
                text = Text("\(text) · ringing")
            }
        } else if endedAt == nil {
            text = Text("\(text) · dismissed")
        }
        if snoozeCount > 0 {
            text = Text("\(text) · snoozed \(snoozeCount)× (\(formatDuration(snoozedSeconds)))")
        }
        return text
    }
}

// MARK: - System alarms (AlarmKit)

/// Extra data carried by each system alarm, for its Lock Screen view.
struct BlockAlarmMetadata: AlarmMetadata {
    var blockTitle: String
}

/// Rings block alerts through AlarmKit, the system behind the Clock app.
/// They sound even in silent mode, show on the Lock Screen, and can be
/// snoozed or stopped there without opening the app.
///
/// Each block's alarm uses the block's `uid` as its id. The block's
/// `alertDueAt` is the source of truth; `watch` keeps the two in step.
enum BlockAlarms {
    /// Length of a snooze started from the system alert. The in-app banner
    /// offers other lengths.
    static let snoozeLength: TimeInterval = 5 * 60

    /// Schedule, or replace, the system alarm for this block's `alertDueAt`.
    static func schedule(_ block: Block) {
        guard let due = block.alertDueAt, block.endedAt == nil else {
            cancel(block)
            return
        }
        let id = block.uid
        let kind = block.alertKind ?? .timer
        let title = block.title

        Task {
            guard await isAuthorized() else { return }
            let manager = AlarmManager.shared
            try? manager.stop(id: id)
            try? manager.cancel(id: id)

            let alert = AlarmPresentation.Alert(
                title: kind == .alarm ? "Alarm" : "Timer done",
                secondaryButton: AlarmButton(text: "Snooze", textColor: .white, systemImageName: "zzz"),
                secondaryButtonBehavior: .countdown)
            let presentation = AlarmPresentation(
                alert: alert,
                countdown: AlarmPresentation.Countdown(title: LocalizedStringResource(stringLiteral: title)))
            let attributes = AlarmAttributes(
                presentation: presentation,
                metadata: BlockAlarmMetadata(blockTitle: title),
                tintColor: .orange)

            // A timer counts down, and the countdown shows on the Lock Screen.
            // An alarm waits for a clock time. Both snooze by `snoozeLength`.
            let configuration: AlarmManager.AlarmConfiguration<BlockAlarmMetadata>
            switch kind {
            case .timer:
                configuration = .init(
                    countdownDuration: .init(preAlert: max(1, due.timeIntervalSinceNow), postAlert: snoozeLength),
                    attributes: attributes)
            case .alarm:
                configuration = .init(
                    countdownDuration: .init(preAlert: nil, postAlert: snoozeLength),
                    schedule: .fixed(due),
                    attributes: attributes)
            }
            do {
                _ = try await manager.schedule(id: id, configuration: configuration)
            } catch {
                print("TimeBlocks: could not schedule alarm: \(error)")
            }
        }
    }

    /// Silence and remove the system alarm for this block, if any.
    static func cancel(_ block: Block) {
        try? AlarmManager.shared.stop(id: block.uid)
        try? AlarmManager.shared.cancel(id: block.uid)
    }

    /// Ask for permission the first time. If the user says no, alerts
    /// still show in the app while it is open.
    static func isAuthorized() async -> Bool {
        let manager = AlarmManager.shared
        switch manager.authorizationState {
        case .authorized:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await manager.requestAuthorization()) == .authorized
        @unknown default:
            return false
        }
    }

    /// Follow the system alarms and copy what the user did on the Lock
    /// Screen back into the blocks. Runs for as long as the app does.
    @MainActor
    static func watch(_ context: ModelContext) async {
        for await alarms in AlarmManager.shared.alarmUpdates {
            reconcile(alarms, context: context)
        }
    }

    @MainActor
    static func reconcile(_ alarms: [Alarm], context: ModelContext, now: Date = .now) {
        let open = (try? context.fetch(FetchDescriptor<Block>(
            predicate: #Predicate { $0.endedAt == nil && $0.alertDueAt != nil }))) ?? []
        let byID = Dictionary(alarms.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for block in open {
            guard let due = block.alertDueAt, due <= now else {
                // Not due yet. A missing alarm may still be on its way.
                continue
            }
            switch byID[block.uid]?.state {
            case nil:
                // It rang and is gone: the user stopped it.
                block.alertDueAt = nil
            case .countdown?:
                // It rang and is counting down again: the user snoozed it.
                block.snoozeCount += 1
                block.snoozedSeconds += snoozeLength
                block.alertDueAt = now.addingTimeInterval(snoozeLength)
            default:
                break
            }
        }

        // Remove system alarms whose block has ended or no longer wants one.
        let wanted = Set(open.filter { $0.alertDueAt != nil }.map(\.uid))
        for alarm in alarms where !wanted.contains(alarm.id) {
            try? AlarmManager.shared.stop(id: alarm.id)
            try? AlarmManager.shared.cancel(id: alarm.id)
        }
    }
}
