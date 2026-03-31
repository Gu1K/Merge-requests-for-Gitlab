import SwiftUI
import AppKit

@main
struct Merge_requests_for_GitlabApp: App {
    @AppStorage("gitlabToken") private var apiToken: String = ""
    
    var body: some Scene {
        MenuBarExtra("GitLab MR", systemImage: "tray.and.arrow.down.fill") {
            let maxHeight: CGFloat = 1000
            let screenHeight = NSScreen.main?.visibleFrame.height ?? maxHeight
            let preferredHeight = min(screenHeight * 0.7, maxHeight)
            ContentView()
                .frame(width: 500, height: preferredHeight)
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
        }
    }
}
