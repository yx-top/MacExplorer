import SwiftUI

@main
struct MacExplorerApp: App {
    init() {
        InputEventTracker.install()
    }

    var body: some Scene {
        WindowGroup("MacExplorer", id: "browser") {
            BrowserWindow()
        }
        .commands {
            AppCommands()
        }
    }
}

private struct BrowserWindow: View {
    @StateObject private var browserStore = BrowserStore()

    var body: some View {
        RootView()
            .environmentObject(browserStore)
            .focusedSceneObject(browserStore)
            .frame(minWidth: 1240, minHeight: 720)
    }
}
