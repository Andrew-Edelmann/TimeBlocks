import SwiftUI
import SwiftData

@main
struct TimeBlocksApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Copy snoozes and stops done on the Lock Screen into the blocks.
                .task { await BlockAlarms.watch(Store.container.mainContext) }
        }
        .modelContainer(Store.container)
    }
}
