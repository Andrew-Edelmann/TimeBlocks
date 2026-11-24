import SwiftUI
import SwiftData
import UserNotifications

@main
struct TimeBlocksApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Session.self, Block.self, Tag.self])
    }
}
