import AppIntents
import SwiftData

// The Lock Screen buttons. The widget only draws them; when tapped, iOS
// runs `perform` inside the app (in the background if it is not open).
// The widget target builds with WIDGET_EXTENSION, and its copy of
// `perform` does nothing.

/// End the current block and start the next one, as in the app.
struct NextBlockIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Next block"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let context = Store.container.mainContext
        if let session = try runningSession(in: context) {
            session.nextBlock(in: context)
            try context.save()
        }
        #endif
        return .result()
    }
}

/// End every open block and the session, as in the app.
struct StopSessionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop session"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let context = Store.container.mainContext
        if let session = try runningSession(in: context) {
            session.stop()
            try context.save()
        }
        #endif
        return .result()
    }
}

@MainActor
private func runningSession(in context: ModelContext) throws -> Session? {
    try context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.endedAt == nil })).first
}
