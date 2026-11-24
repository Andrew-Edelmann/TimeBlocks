import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TrackView()
                .tabItem { Label("Track", systemImage: "stopwatch") }
            HistoryView()
                .tabItem { Label("History", systemImage: "list.bullet") }
        }
    }
}
