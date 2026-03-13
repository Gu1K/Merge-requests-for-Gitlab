import SwiftUI

@main
struct Merge_requests_for_GitlabApp: App {
    // Stocke le token de manière sécurisée dans les préférences de l'utilisateur
    @AppStorage("gitlabToken") private var apiToken: String = ""
    
    var body: some Scene {
        // Crée l'icône dans la barre de menu
        MenuBarExtra("GitLab MR", systemImage: "tray.and.arrow.down.fill") {
            ContentView()
                .frame(width: 320, height: 450)
        }
        .menuBarExtraStyle(.window)
        
        // Ajoute la fenêtre de réglages standard macOS (Cmd + ,)
        Settings {
            SettingsView()
        }
    }
}
