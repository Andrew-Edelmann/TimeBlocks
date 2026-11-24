import SwiftUI
import WidgetKit

/// The widget extension holds no home-screen widgets, only the views for
/// the app's Live Activities.
@main
struct TimeBlocksWidgetBundle: WidgetBundle {
    var body: some Widget {
        BlockLiveActivity()
        AlarmLiveActivity()
    }
}
