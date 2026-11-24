import SwiftUI

/// Shows one block: its tags, when it happened, and how long it lasted.
/// `depth` indents blocks that sit inside other blocks.
struct BlockRow: View {
    let block: Block
    var depth: Int = 0

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(block.title)
                        .foregroundStyle(block.tags?.isEmpty ?? true ? .secondary : .primary)
                    if let kind = block.alertKind {
                        Image(systemName: kind == .alarm ? "alarm" : "timer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !block.note.isEmpty {
                    Text(block.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(timeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Group {
                if block.endedAt == nil {
                    ElapsedClock(since: block.startedAt)
                } else {
                    Text(formatDuration(block.duration()))
                }
            }
            .font(.body.monospacedDigit())
        }
        .padding(.leading, CGFloat(depth) * 18)
    }

    private var timeRange: String {
        let style = Date.FormatStyle().hour().minute().second()
        let start = block.startedAt.formatted(style)
        guard let end = block.endedAt else { return "\(start) – now" }
        return "\(start) – \(end.formatted(style))"
    }
}

/// A clock counting up from `start`. The system draws and updates it, so
/// the app's views are not re-run every second while it ticks.
struct ElapsedClock: View {
    let start: Date
    var alignment: TextAlignment = .trailing

    init(since start: Date, alignment: TextAlignment = .trailing) {
        self.start = start
        self.alignment = alignment
    }

    var body: some View {
        Text(start, style: .timer)
            .monospacedDigit()
            .multilineTextAlignment(alignment)
    }
}
