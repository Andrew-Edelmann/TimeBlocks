import SwiftUI
import SwiftData

struct TrackView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<Session> { $0.endedAt == nil })
    private var running: [Session]

    var body: some View {
        NavigationStack {
            Group {
                if let session = running.first {
                    RunningView(session: session)
                } else {
                    VStack {
                        Spacer()
                        Button {
                            Session.start(in: context)
                        } label: {
                            Text("Start")
                                .font(.title2.bold())
                                .frame(maxWidth: 240)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Track")
        }
        // Start a new day's session at midnight (open blocks carry over).
        // The wait costs no battery: the task sleeps until midnight, and if
        // the app is suspended it simply runs late, on the next foreground.
        .task(id: running.first?.persistentModelID) {
            while !Task.isCancelled {
                running.first?.rollOverIfNeeded()
                let calendar = Calendar.current
                let midnight = calendar.date(byAdding: .day, value: 1,
                                             to: calendar.startOfDay(for: .now)) ?? .now
                try? await Task.sleep(for: .seconds(max(1, midnight.timeIntervalSinceNow + 0.5)))
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active { running.first?.rollOverIfNeeded() }
        }
    }
}

private struct RunningView: View {
    @Environment(\.modelContext) private var context
    let session: Session

    var body: some View {
        // The clocks below are drawn by the system and tick on their own.
        // This view only needs to re-run when a timer or alarm becomes due,
        // so the "ringing" banner can appear. It does not redraw every second.
        TimelineView(.explicit(session.alertDueDates)) { _ in
            let now = Date.now
            VStack(spacing: 16) {
                // Big clock: the current block
                VStack(spacing: 4) {
                    if let block = session.currentBlock {
                        ElapsedClock(since: block.startedAt, alignment: .center)
                            .font(.system(size: 64, weight: .light))
                    }
                    Text("Session \(session.startedAt, style: .timer)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Any timer or alarm that is due, including on outer blocks
                ForEach((session.blocks ?? []).filter { $0.isRinging(at: now) },
                        id: \.persistentModelID) { block in
                    RingingBanner(block: block)
                        .padding(.horizontal)
                }

                if let block = session.currentBlock {
                    // Where we are, e.g. "Inside: Doing groceries"
                    let outer = block.path.dropLast()
                    if !outer.isEmpty {
                        Text("Inside: " + outer.map(\.title).joined(separator: " › "))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    CurrentBlockEditor(block: block, now: now)
                        .id(block.persistentModelID)   // fresh state for each new block
                        .padding(.horizontal)
                }

                VStack(spacing: 10) {
                    Button {
                        session.nextBlock(in: context)
                    } label: {
                        Text("Next block")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)

                    HStack(spacing: 10) {
                        Button("Start inside") {
                            session.nest(in: context)
                        }
                        if session.currentBlock?.parent != nil {
                            Button("End block") {
                                session.endCurrent()
                            }
                        }
                        Button("Stop", role: .destructive) {
                            session.stop()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
                .padding(.horizontal)

                // Everything else in this session, in tree order.
                // Open outer blocks show here with a running clock.
                let currentID = session.currentBlock?.persistentModelID
                List(session.flattened().filter { $0.id != currentID }) { item in
                    BlockRow(block: item.block, depth: item.depth)
                }
                .listStyle(.plain)
            }
        }
        // Keep the Lock Screen Live Activity in step: when this screen
        // appears (e.g. after a relaunch) and when tags change the title.
        .onAppear { BlockActivityController.sync(session) }
        .onChange(of: liveActivityKey) { BlockActivityController.sync(session) }
    }

    /// Everything the Live Activity shows that tag edits can change.
    private var liveActivityKey: String {
        session.currentBlock?.path.map(\.title).joined(separator: " › ") ?? ""
    }
}

/// Tags, timer or alarm, and note for the block that is running now.
private struct CurrentBlockEditor: View {
    @Bindable var block: Block
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TagPicker(block: block)
            AlertControl(block: block, now: now)
            TextField("Note (optional)", text: $block.note, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
        }
    }
}
