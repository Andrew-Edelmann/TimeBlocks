import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Session> { $0.endedAt != nil },
           sort: \Session.startedAt, order: .reverse)
    private var sessions: [Session]

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    NavigationLink {
                        SessionDetailView(session: session)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                            Text("\(session.blocks?.count ?? 0) blocks · \(formatDuration(session.duration()))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(sessions[index]) }
                }
            }
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView("No sessions yet",
                                           systemImage: "stopwatch",
                                           description: Text("Finished sessions show up here."))
                }
            }
            .navigationTitle("History")
        }
    }
}

struct SessionDetailView: View {
    @Environment(\.modelContext) private var context
    let session: Session
    @State private var selection = Set<PersistentIdentifier>()

    var body: some View {
        List(session.flattened(), selection: $selection) { item in
            NavigationLink {
                BlockEditView(block: item.block)
            } label: {
                BlockRow(block: item.block, depth: item.depth)
            }
        }
        .navigationTitle(session.startedAt.formatted(date: .abbreviated, time: .shortened))
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            #endif
            ToolbarItem {
                Button("Group") { group() }
                    .disabled(groupable == nil)
            }
        }
    }

    /// The selected blocks, if they can be grouped: all siblings, and next
    /// to each other. Otherwise nil.
    private var groupable: [Block]? {
        let chosen = session.flattened().map(\.block)
            .filter { selection.contains($0.persistentModelID) }
        guard let first = chosen.first else { return nil }
        let parent = first.parent
        guard chosen.allSatisfy({ $0.parent?.persistentModelID == parent?.persistentModelID })
        else { return nil }

        let siblings = (parent?.children ?? (session.blocks ?? []).filter { $0.parent == nil })
            .sorted { $0.startedAt < $1.startedAt }
        let picked = siblings.indices.filter { selection.contains(siblings[$0].persistentModelID) }
        guard let low = picked.first, let high = picked.last,
              high - low + 1 == picked.count, picked.count == chosen.count
        else { return nil }
        return Array(siblings[low...high])
    }

    /// Wrap the selected blocks in a new parent block that spans them.
    private func group() {
        guard let chosen = groupable, let first = chosen.first, let last = chosen.last else { return }
        let outer = Block(startedAt: first.startedAt)
        outer.endedAt = last.endedAt
        context.insert(outer)
        outer.session = session
        outer.parent = first.parent
        for block in chosen { block.parent = outer }
        selection = []
    }
}

struct BlockEditView: View {
    @Bindable var block: Block

    var body: some View {
        Form {
            Section("Tags") {
                TagPicker(block: block)
            }
            Section("Note") {
                TextField("Note", text: $block.note, axis: .vertical)
                    .lineLimit(1...6)
            }
            if let kind = block.alertKind {
                Section("Alert") {
                    LabeledContent("Type", value: kind == .timer ? "Timer" : "Alarm")
                    if let seconds = block.timerSeconds {
                        LabeledContent("Length", value: formatDuration(seconds))
                    }
                    if let set = block.alertSetAt {
                        LabeledContent("Set at", value: set.formatted(date: .omitted, time: .standard))
                    }
                    if let target = block.alertTargetAt {
                        LabeledContent("First due", value: target.formatted(date: .omitted, time: .standard))
                    }
                    LabeledContent("Times snoozed", value: "\(block.snoozeCount)")
                    LabeledContent("Total snoozed", value: formatDuration(block.snoozedSeconds))
                }
            }
            Section("Time") {
                LabeledContent("Start", value: block.startedAt.formatted(date: .omitted, time: .standard))
                if let end = block.endedAt {
                    LabeledContent("End", value: end.formatted(date: .omitted, time: .standard))
                }
                LabeledContent("Duration", value: formatDuration(block.duration()))
            }
        }
        .navigationTitle("Block")
    }
}
