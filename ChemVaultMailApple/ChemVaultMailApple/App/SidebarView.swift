import SwiftUI

struct SidebarView: View {
    @Binding var selection: AppRoute
    @EnvironmentObject private var authSession: AuthSession

    var body: some View {
        List {
            ForEach(groupedRoutes, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.routes) { route in
                        Button {
                            selection = route
                        } label: {
                            SidebarRouteRow(
                                route: route,
                                isSelected: selection == route,
                                isAvailable: route.isAvailable(for: authSession.currentUser)
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(selection == route ? Color.accentColor.opacity(0.12) : Color.clear)
                    }
                }
            }
        }
        .navigationTitle("ChemVault Mail")
        #if os(macOS)
        .listStyle(.sidebar)
        #endif
    }

    private var groupedRoutes: [(title: String, routes: [AppRoute])] {
        let order = ["Mail", "Personal", "Admin", "Insights"]
        return order.compactMap { title in
            let routes = AppRoute.allCases.filter { $0.groupTitle == title }
            return routes.isEmpty ? nil : (title, routes)
        }
    }
}

private struct SidebarRouteRow: View {
    let route: AppRoute
    let isSelected: Bool
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: route.systemImage)
                .frame(width: 20)
            Text(route.title)
            Spacer()
            if !isAvailable {
                Image(systemName: "lock")
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
    }
}
