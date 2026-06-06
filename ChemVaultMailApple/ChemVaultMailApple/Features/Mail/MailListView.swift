import SwiftUI

struct MailListView: View {
    let mode: MailboxMode

    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var store = MailStore()
    @State private var showingCompose = false

    var body: some View {
        Group {
            #if os(macOS)
            splitLayout
            #else
            if horizontalSizeClass == .compact {
                compactLayout
            } else {
                splitLayout
            }
            #endif
        }
        .sheet(isPresented: $showingCompose) {
            ComposeView()
                .environmentObject(appEnvironment)
        }
        .task {
            await store.load(mode: mode, apiClient: appEnvironment.apiClient)
        }
        .onReceive(NotificationCenter.default.publisher(for: .chemVaultRefreshRequested)) { _ in
            Task { await store.load(mode: mode, apiClient: appEnvironment.apiClient) }
        }
    }

    private var splitLayout: some View {
        NavigationSplitView {
            mailList
        } detail: {
            if let selectedEmail = store.selectedEmail {
                detailView(for: selectedEmail)
                    .id(selectedEmail.emailId)
                    .transition(.opacity.combined(with: .scale(scale: 0.99)))
            } else {
                ChemVaultMailPlaceholder(mode: mode)
            }
        }
    }

    private var compactLayout: some View {
        mailList
    }

    private var mailList: some View {
        List {
            Section {
                MailboxOverviewCard(
                    mode: mode,
                    visibleCount: store.emails.count,
                    totalCount: store.total,
                    unreadCount: store.emails.filter(\.isUnread).count,
                    latestEmail: store.latestEmail,
                    isLoading: store.isLoading
                )
                .listRowInsets(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if store.isLoading && store.emails.isEmpty {
                Section {
                    ChemVaultLoadingView(
                        title: "Syncing \(mode.title)",
                        subtitle: "Checking ChemVault mail",
                        size: 30,
                        presentation: .inline
                    )
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }

            ForEach(store.emails) { email in
                row(for: email)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ChemVaultWorkspaceBackground())
        .overlay {
            if store.emails.isEmpty && !store.isLoading {
                ChemVaultMailEmptyState(mode: mode, message: store.errorMessage)
            }
        }
        .navigationTitle(mode.title)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await store.load(mode: mode, apiClient: appEnvironment.apiClient) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    Task { await store.markVisibleUnreadRead(apiClient: appEnvironment.apiClient) }
                } label: {
                    Label("Mark All Read", systemImage: "envelope.open")
                }
                .disabled(visibleUnreadCount == 0 || store.isLoading)

                Button {
                    showingCompose = true
                } label: {
                    Label("Compose", systemImage: "square.and.pencil")
                }
            }
        }
        .refreshable {
            await store.load(mode: mode, apiClient: appEnvironment.apiClient)
        }
        .animation(reduceMotion ? nil : ChemVaultMotion.rootContent, value: store.emails)
        .animation(reduceMotion ? nil : ChemVaultMotion.fieldFocus, value: store.isLoading)
    }

    private var visibleUnreadCount: Int {
        store.emails.filter(\.isUnread).count
    }

    @ViewBuilder
    private func row(for email: ChemVaultEmail) -> some View {
        #if os(macOS)
        selectableRow(for: email)
        #else
        if horizontalSizeClass == .compact {
            NavigationLink {
                detailView(for: email)
            } label: {
                MailRowView(email: email)
            }
            .contextMenu {
                compactRowActions(for: email)
            }
        } else {
            selectableRow(for: email)
        }
        #endif
    }

    private func selectableRow(for email: ChemVaultEmail) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : ChemVaultMotion.rootContent) {
                store.selectedEmail = email
            }
        } label: {
            MailRowView(email: email, isSelected: store.selectedEmail?.emailId == email.emailId)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .contextMenu {
            compactRowActions(for: email)
        }
    }

    @ViewBuilder
    private func compactRowActions(for email: ChemVaultEmail) -> some View {
        if email.isUnread {
            Button("Mark Read") {
                Task { await store.markRead(email: email, apiClient: appEnvironment.apiClient) }
            }
        }
        Button(email.starred ? "Unstar" : "Star") {
            Task { await store.toggleStar(email: email, apiClient: appEnvironment.apiClient) }
        }
        Button("Delete", role: .destructive) {
            Task { await store.delete(email: email, apiClient: appEnvironment.apiClient) }
        }
    }

    private func detailView(for email: ChemVaultEmail) -> some View {
        MailDetailView(
            email: email,
            markRead: { Task { await store.markRead(email: email, apiClient: appEnvironment.apiClient) } },
            delete: { Task { await store.delete(email: email, apiClient: appEnvironment.apiClient) } },
            toggleStar: { Task { await store.toggleStar(email: email, apiClient: appEnvironment.apiClient) } }
        )
    }
}

struct MailRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    let email: ChemVaultEmail
    var isSelected = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MailSenderAvatar(email: email)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(email.senderLine)
                        .font(.headline.weight(email.isUnread ? .semibold : .regular))
                        .lineLimit(1)

                    if email.isUnread {
                        Circle()
                            .fill(ChemVaultLoadingConfiguration.primaryColor(for: colorScheme))
                            .frame(width: 7, height: 7)
                    }

                    Spacer(minLength: 8)

                    if let createTime = email.createTime {
                        Text(createTime)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Text(email.title)
                    .font(email.isUnread ? .subheadline.weight(.semibold) : .subheadline)
                    .foregroundStyle(ChemVaultTheme.brandText(for: colorScheme))
                    .lineLimit(1)

                if !email.previewText.isEmpty {
                    Text(email.previewText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if email.starred {
                        Label("Starred", systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                    if email.attList?.isEmpty == false {
                        Label("Attachment", systemImage: "paperclip")
                            .foregroundStyle(ChemVaultTheme.mutedText(for: colorScheme))
                    }
                    if let toEmail = email.toEmail, !toEmail.isEmpty {
                        Label(toEmail, systemImage: "arrow.down.forward")
                            .foregroundStyle(ChemVaultTheme.mutedText(for: colorScheme))
                            .lineLimit(1)
                    }
                }
                .font(.caption2.weight(.medium))
            }
        }
        .padding(12)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? ChemVaultLoadingConfiguration.primaryColor(for: colorScheme).opacity(0.32) : ChemVaultWorkspaceTheme.panelStroke(for: colorScheme), lineWidth: 1)
        }
        .shadow(color: isSelected ? ChemVaultWorkspaceTheme.panelShadow(for: colorScheme) : .clear, radius: 12, x: 0, y: 7)
        .scaleEffect(isSelected ? 1.01 : 1)
        .animation(ChemVaultMotion.fieldFocus, value: isSelected)
    }

    private var rowBackground: Color {
        isSelected
            ? ChemVaultWorkspaceTheme.selectedBackground(for: colorScheme)
            : ChemVaultWorkspaceTheme.panelBackground(for: colorScheme)
    }
}

private struct MailSenderAvatar: View {
    @Environment(\.colorScheme) private var colorScheme
    let email: ChemVaultEmail

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ChemVaultLoadingConfiguration.primaryColor(for: colorScheme).opacity(email.isUnread ? 0.16 : 0.09))
                .frame(width: 40, height: 40)

            Text(initials)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ChemVaultLoadingConfiguration.primaryColor(for: colorScheme))
        }
    }

    private var initials: String {
        let source = email.name?.nilIfBlank ?? email.sendEmail ?? email.toEmail ?? "CV"
        let parts = source
            .split { !$0.isLetter && !$0.isNumber }
            .prefix(2)
        let value = parts.compactMap(\.first).map { String($0).uppercased() }.joined()
        return value.isEmpty ? "CV" : value
    }
}

private struct MailboxOverviewCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let mode: MailboxMode
    let visibleCount: Int
    let totalCount: Int?
    let unreadCount: Int
    let latestEmail: ChemVaultEmail?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: mode == .inbox ? "tray.full.fill" : "star.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(
                            colors: ChemVaultTheme.primaryButtonColors(for: colorScheme),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title)
                        .font(.headline.weight(.semibold))
                    Text(isLoading ? "Refreshing mailbox" : latestDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isLoading {
                    ChemVaultLoadingMark(size: 24, showsTrack: true)
                }
            }

            HStack(spacing: 8) {
                MailboxMetricPill(title: "Visible", value: "\(visibleCount)")
                MailboxMetricPill(title: "Unread", value: "\(unreadCount)")
                MailboxMetricPill(title: "Total", value: totalLabel)
            }
        }
        .padding(14)
        .background(ChemVaultWorkspaceTheme.panelBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ChemVaultWorkspaceTheme.panelStroke(for: colorScheme), lineWidth: 1)
        }
        .shadow(color: ChemVaultWorkspaceTheme.panelShadow(for: colorScheme), radius: 14, x: 0, y: 8)
    }

    private var totalLabel: String {
        totalCount.map(String.init) ?? "-"
    }

    private var latestDescription: String {
        guard let latestEmail else { return "No recent activity" }
        return "Latest: \(latestEmail.senderLine)"
    }
}

private struct MailboxMetricPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(ChemVaultTheme.fieldBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ChemVaultMailPlaceholder: View {
    @Environment(\.colorScheme) private var colorScheme
    let mode: MailboxMode

    var body: some View {
        ZStack {
            ChemVaultWorkspaceBackground()
            VStack(spacing: 14) {
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(ChemVaultLoadingConfiguration.primaryColor(for: colorScheme))
                Text("Select a message")
                    .font(.title3.weight(.semibold))
                Text("Choose a message from \(mode.title.lowercased()) to read it here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
        }
    }
}

private struct ChemVaultMailEmptyState: View {
    @Environment(\.colorScheme) private var colorScheme
    let mode: MailboxMode
    let message: String?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: mode == .inbox ? "tray" : "star")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(ChemVaultLoadingConfiguration.primaryColor(for: colorScheme))
            Text(mode.title)
                .font(.headline.weight(.semibold))
            Text(message ?? "No messages to show.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(26)
        .background(ChemVaultWorkspaceTheme.panelBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ChemVaultWorkspaceTheme.panelStroke(for: colorScheme), lineWidth: 1)
        }
        .padding()
    }
}
