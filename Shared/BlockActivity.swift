import Foundation
import ActivityKit

/// The Live Activity shown on the Lock Screen and in the Dynamic Island
/// while a session runs. Its clocks are drawn by the system from the
/// start dates below, so the app does not need to update it every second.
/// It is only updated when the current block changes.
struct BlockActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// The current block's tags, or "Untagged".
        var blockTitle: String
        /// The blocks it sits inside, e.g. "Doing groceries", or "" at the top level.
        var inside: String
        var blockStartedAt: Date
        var sessionStartedAt: Date
    }
}

extension BlockActivityAttributes.ContentState {
    init(session: Session, block: Block) {
        blockTitle = block.title
        inside = block.path.dropLast().map(\.title).joined(separator: " › ")
        blockStartedAt = block.startedAt
        sessionStartedAt = session.startedAt
    }
}

/// Starts, updates and ends the Live Activity to match the running session.
@MainActor
enum BlockActivityController {
    /// Updates run one after another, so a quick "Next block, Next block"
    /// cannot leave the Lock Screen showing an older block.
    private static var pending: Task<Void, Never>?

    /// Make the Live Activity match `session`: show its current block while
    /// it runs, and remove the activity once it has stopped.
    static func sync(_ session: Session) {
        let state: BlockActivityAttributes.ContentState? =
            session.isRunning
                ? session.currentBlock.map { .init(session: session, block: $0) }
                : nil
        let previous = pending
        pending = Task {
            await previous?.value
            await apply(state)
        }
    }

    private static func apply(_ state: BlockActivityAttributes.ContentState?) async {
        let activities = Activity<BlockActivityAttributes>.activities
        guard let state else {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }
        let content = ActivityContent(state: state, staleDate: nil)
        if let activity = activities.first {
            await activity.update(content)
            for extra in activities.dropFirst() {
                await extra.end(nil, dismissalPolicy: .immediate)
            }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            do {
                _ = try Activity.request(attributes: BlockActivityAttributes(), content: content)
            } catch {
                print("TimeBlocks: could not start Live Activity: \(error)")
            }
        }
    }
}
