import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

/// The Lock Screen view AlarmKit needs for a block's timer or alarm while
/// it counts down (and while it counts down again after a snooze). The
/// ringing alert itself is drawn by the system.
struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<BlockAlarmMetadata>.self) { context in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(caption(context.state))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(context.attributes.metadata?.blockTitle ?? "Block")
                        .font(.headline)
                        .lineLimit(1)
                }
                Spacer()
                Countdown(state: context.state)
                    .font(.title.monospacedDigit())
            }
            .padding()
            .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.metadata?.blockTitle ?? "Block")
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(state: context.state)
                        .font(.title2.monospacedDigit())
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                Countdown(state: context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(context.attributes.tintColor)
            }
        }
    }

    private func caption(_ state: AlarmPresentationState) -> String {
        switch state.mode {
        case .alert: "Ringing"
        case .paused: "Paused"
        default: "Timer"
        }
    }
}

/// Time left, drawn by the system.
private struct Countdown: View {
    let state: AlarmPresentationState

    var body: some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(timerInterval: Date.now...max(Date.now, countdown.fireDate), countsDown: true)
                .multilineTextAlignment(.trailing)
        case .paused(let paused):
            Text(formatDuration(paused.totalCountdownDuration - paused.previouslyElapsedDuration))
        default:
            Image(systemName: "bell.and.waves.left.and.right")
        }
    }
}
