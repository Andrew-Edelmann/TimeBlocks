import SwiftUI

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
                Label {
                    block.alertSummary(now: now)
                } icon: {
                    Image(systemName: block.alertKind == .alarm ? "alarm" : "timer")
                }
                .font(.footnote.monospacedDigit())
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
