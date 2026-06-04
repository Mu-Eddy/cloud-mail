import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authSession: AuthSession

    var body: some View {
        Group {
            switch authSession.state {
            case .checking:
                ProgressView("Loading ChemVault Mail")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .signedOut:
                LoginView()
            case .signedIn:
                AppShellView()
            }
        }
        .task {
            await authSession.bootstrap()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppEnvironment().authSession)
        .environmentObject(AppEnvironment())
}

