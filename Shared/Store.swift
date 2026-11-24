import SwiftData

/// The one database the app uses. The app's views and the Lock Screen
/// buttons (which run inside the app) share it, so both see the same data.
@MainActor
enum Store {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: Session.self, Block.self, Tag.self)
        } catch {
            fatalError("TimeBlocks: could not open the database: \(error)")
        }
    }()
}
