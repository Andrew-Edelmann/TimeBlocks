import Foundation
import SwiftData

/// One run of the stopwatch, from Start to Stop.
@Model
final class Session {
    var startedAt: Date = Date.now
    var endedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Block.session)
    var blocks: [Block]? = []

    init(startedAt: Date = .now) {
        self.startedAt = startedAt
    }

    var isRunning: Bool { endedAt == nil }

    /// Blocks in the order they happened.
    var sortedBlocks: [Block] {
        (blocks ?? []).sorted { $0.startedAt < $1.startedAt }
    }

    /// The innermost open block: open, with no open block inside it.
    /// Open blocks always form a chain, e.g. "Groceries" > "Biking there".
    var currentBlock: Block? {
        sortedBlocks.last { block in
            block.endedAt == nil
                && !(block.children ?? []).contains { $0.endedAt == nil }
        }
    }

    /// All blocks in tree order (parent, then its children), with depth.
    func flattened() -> [BlockItem] {
        var result: [BlockItem] = []
        func walk(_ blocks: [Block], _ depth: Int) {
            for block in blocks.sorted(by: { $0.startedAt < $1.startedAt }) {
                result.append(BlockItem(block: block, depth: depth))
                walk(block.children ?? [], depth + 1)
            }
        }
        walk((blocks ?? []).filter { $0.parent == nil }, 0)
        return result
    }

    func duration(at now: Date = .now) -> TimeInterval {
        (endedAt ?? now).timeIntervalSince(startedAt)
    }

    /// Start a session with its first block.
    static func start(in context: ModelContext, at now: Date = .now) {
        let session = Session(startedAt: now)
        context.insert(session)
        let block = Block(startedAt: now)
        context.insert(block)
        block.session = session
    }

    /// Close the current block and open a sibling at the same instant.
    /// Using one timestamp for both means there is no gap between blocks.
    func nextBlock(in context: ModelContext, at now: Date = .now) {
        let current = currentBlock
        current?.close(at: now)
        let block = Block(startedAt: now)
        context.insert(block)
        block.session = self
        block.parent = current?.parent
    }

    /// Open a block inside the current one. The current block keeps running.
    func nest(in context: ModelContext, at now: Date = .now) {
        let block = Block(startedAt: now)
        context.insert(block)
        block.session = self
        block.parent = currentBlock
    }

    /// Close the current block. Its parent, if any, becomes current.
    /// If there is no parent, the session ends.
    func endCurrent(at now: Date = .now) {
        guard let current = currentBlock else { return }
        current.close(at: now)
        if current.parent == nil { endedAt = now }
    }

    /// Close every open block and end the session.
    func stop(at now: Date = .now) {
        for block in blocks ?? [] where block.endedAt == nil {
            block.close(at: now)
        }
        endedAt = now
    }
}

/// One lap: a block of time with a start, an end, and details about it.
@Model
final class Block {
    var startedAt: Date = Date.now
    var endedAt: Date?
    var note: String = ""
    var session: Session?
    var tags: [Tag]? = []

    /// Stable id, used to name this block's notification.
    var uid: UUID = UUID()

    // Timer or alarm (one per block). See Alerts.swift.
    var alertKindRaw: String?        // "timer" or "alarm"
    var alertSetAt: Date?            // when the user set it
    var timerSeconds: Double?        // timer length (timers only)
    var alertTargetAt: Date?         // when it was first meant to ring
    var alertDueAt: Date?            // when it rings next; nil once dismissed or the block ends
    var snoozeCount: Int = 0
    var snoozedSeconds: Double = 0   // total time snoozed

    /// The block this one sits inside, if any. A parent spans its children.
    var parent: Block?
    @Relationship(deleteRule: .cascade, inverse: \Block.parent)
    var children: [Block]? = []

    init(startedAt: Date = .now, note: String = "") {
        self.startedAt = startedAt
        self.note = note
    }

    var sortedTags: [Tag] {
        (tags ?? []).sorted { ($0.key, $0.value) < ($1.key, $1.value) }
    }

    /// Tags joined for display, or "Untagged".
    var title: String {
        tags?.isEmpty ?? true
            ? "Untagged"
            : sortedTags.map(\.displayName).joined(separator: " · ")
    }

    /// From the outermost ancestor down to this block.
    var path: [Block] {
        var result = [self]
        var next = parent
        while let block = next {
            result.insert(block, at: 0)
            next = block.parent
        }
        return result
    }

    func hasTag(_ tag: Tag) -> Bool {
        (tags ?? []).contains { $0.persistentModelID == tag.persistentModelID }
    }

    func toggle(_ tag: Tag) {
        if hasTag(tag) {
            tags?.removeAll { $0.persistentModelID == tag.persistentModelID }
        } else {
            tags = (tags ?? []) + [tag]
        }
    }

    func duration(at now: Date = .now) -> TimeInterval {
        (endedAt ?? now).timeIntervalSince(startedAt)
    }
}

/// A block with its nesting depth, for showing the tree as a flat list.
struct BlockItem: Identifiable {
    let block: Block
    let depth: Int
    var id: PersistentIdentifier { block.persistentModelID }
}

/// A key-value pair the user defines. The value is optional, so a tag
/// can be plain ("focus") or structured ("project: thesis").
/// Tags are stored once and reused across blocks.
@Model
final class Tag {
    var key: String = ""
    var value: String = ""

    @Relationship(inverse: \Block.tags)
    var blocks: [Block]? = []

    init(key: String, value: String = "") {
        self.key = key
        self.value = value
    }

    var displayName: String {
        value.isEmpty ? key : "\(key): \(value)"
    }

    /// Parse "key" or "key: value". Only the first colon splits.
    static func parse(_ text: String) -> (key: String, value: String)? {
        let parts = text.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let key = parts[0].trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        let value = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
        return (key, value)
    }
}

/// "12:34" or "1:02:03"
func formatDuration(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval))
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    return h > 0
        ? String(format: "%d:%02d:%02d", h, m, s)
        : String(format: "%02d:%02d", m, s)
}
