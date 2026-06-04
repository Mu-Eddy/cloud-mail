import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: AppRoute = .mail

    var body: some View {
        #if os(macOS)
        splitLayout
            .frame(minWidth: 980, minHeight: 680)
        #else
        if horizontalSizeClass == .compact {
            compactLayout
        } else {
            splitLayout
        }
        #endif
    }

    private var splitLayout: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            routeContent(selection)
        }
    }

    private var compactLayout: some View {
        TabView(selection: $selection) {
            ForEach(AppRoute.allCases) { route in
                NavigationStack {
                    routeContent(route)
                }
                .tabItem {
                    Label(route.title, systemImage: route.systemImage)
                }
                .tag(route)
            }
        }
    }

    @ViewBuilder
    private func routeContent(_ route: AppRoute) -> some View {
        if route.isAvailable(for: authSession.currentUser) {
            switch route {
            case .mail:
                MailListView(mode: .inbox)
            case .starred:
                MailListView(mode: .starred)
            case .accounts:
                AccountsView()
            case .settings:
                SettingsView()
            case .adminUsers:
                AdminUsersView()
            case .adminRoles:
                AdminRolesView()
            case .adminRegistrationKeys:
                AdminRegistrationKeysView()
            case .adminAllMail:
                AdminAllMailView()
            case .adminSystemSettings:
                SystemSettingsView()
            case .analytics:
                AnalyticsView()
            }
        } else {
            PermissionDeniedView(route: route)
        }
    }
}

struct PermissionDeniedView: View {
    let route: AppRoute

    var body: some View {
        ContentUnavailableView(
            "No Access",
            systemImage: "lock",
            description: Text("Your ChemVault role does not include permission for \(route.title).")
        )
        .navigationTitle(route.title)
    }
}

