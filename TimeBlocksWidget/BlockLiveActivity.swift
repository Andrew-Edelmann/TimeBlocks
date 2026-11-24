import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The running block on the Lock Screen and in the Dynamic Island, with
/// Next block and Stop buttons. All clocks are `Text(date, style: .timer)`,
/// which the system draws and updates without waking the app.
struct BlockLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BlockActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.blockTitle)
                            .font(.headline)
                            .lineLimit(1)
                        if !state.inside.isEmpty {
                            Text("Inside: \(state.inside)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(state.blockStartedAt, style: .timer)
                        .font(.title2.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    BlockButtons()
                }
            } compactLeading: {
                Image(systemName: "stopwatch")
            } compactTrailing: {
                Text(state.blockStartedAt, style: .timer)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "stopwatch")
            }
        }
    }
}

private struct LockScreenView: View {
    let state: BlockActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    if !state.inside.isEmpty {
                        Text("Inside: \(state.inside)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(state.blockTitle)
                        .font(.headline)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(state.blockStartedAt, style: .timer)
                        .font(.title.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                    Text("Session \(state.sessionStartedAt, style: .timer)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            BlockButtons()
        }
        .padding()
    }
}

/// Buttons that run the app's actions without opening it.
private struct BlockButtons: View {
    var body: some View {
        HStack(spacing: 8) {
            Button(intent: NextBlockIntent()) {
                Label("Next block", systemImage: "forward.end")
                    .frame(maxWidth: .infinity)
            }
            .tint(.accentColor)
            Button(intent: StopSessionIntent()) {
                Label("Stop", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .tint(.red)
        }
        .buttonStyle(.bordered)
        .font(.subheadline)
    }
}
