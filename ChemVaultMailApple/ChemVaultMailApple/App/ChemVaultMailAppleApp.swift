import SwiftUI

@main
struct ChemVaultMailAppleApp: App {
    @StateObject private var appEnvironment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appEnvironment)
                .environmentObject(appEnvironment.preferences)
                .environmentObject(appEnvironment.authSession)
        }
        .commands {
            CommandMenu("ChemVault Mail") {
                Button("Refresh") {
                    NotificationCenter.default.post(name: .chemVaultRefreshRequested, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(appEnvironment)
                .environmentObject(appEnvironment.preferences)
                .environmentObject(appEnvironment.authSession)
        }
        #endif
    }
}

extension Notification.Name {
    static let chemVaultRefreshRequested = Notification.Name("chemVaultRefreshRequested")
}

