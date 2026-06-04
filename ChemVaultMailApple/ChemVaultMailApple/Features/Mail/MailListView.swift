import SwiftUI

struct MailListView: View {
    let mode: MailboxMode

    @EnvironmentObject private var appEnvironment: AppEnvironment
    @StateObject private var store = MailStore()
    @State private var showingCompose = false

    var body: some View {
        NavigationSplitView {
            List {
                if store.isLoading && store.emails.isEmpty {
                    ProgressView()
                }

                ForEach(store.emails) { email in
                    Button {
                        store.selectedEmail = email
                    } label: {
                        MailRowView(email: email)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(store.selectedEmail?.emailId == email.emailId ? Color.accentColor.opacity(0.12) : Color.clear)
                    .contextMenu {
                        Button("Mark Read") {
                            store.selectedEmail = email
                            Task { await store.markSelectedRead(apiClient: appEnvironment.apiClient) }
                        }
                    }
                }
            }
            .overlay {
                if store.emails.isEmpty && !store.isLoading {
                    ContentUnavailableView(
                        mode.title,
                        systemImage: mode == .inbox ? "tray" : "star",
                        description: Text(store.errorMessage ?? "No messages to show.")
                    )
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
                        showingCompose = true
                    } label: {
                        Label("Compose", systemImage: "square.and.pencil")
                    }
                }
            }
        } detail: {
            if let selectedEmail = store.selectedEmail {
                MailDetailView(
                    email: selectedEmail,
                    markRead: { Task { await store.markSelectedRead(apiClient: appEnvironment.apiClient) } },
                    delete: { Task { await store.deleteSelected(apiClient: appEnvironment.apiClient) } },
                    toggleStar: { Task { await store.toggleStar(apiClient: appEnvironment.apiClient) } }
                )
            } else {
                ContentUnavailableView("Select a message", systemImage: "envelope.open")
            }
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

}

struct MailRowView: View {
    let email: ChemVaultEmail

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(email.senderLine)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if email.starred {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
            }

            Text(email.title)
                .font(email.isUnread ? .subheadline.weight(.semibold) : .subheadline)
                .lineLimit(1)

            if !email.previewText.isEmpty {
                Text(email.previewText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let createTime = email.createTime {
                Text(createTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }
}
