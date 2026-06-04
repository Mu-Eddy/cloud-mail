import SwiftUI

struct AccountsView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @EnvironmentObject private var authSession: AuthSession
    @State private var accounts: [ChemVaultAccount] = []
    @State private var newEmail = ""
    @State private var isLoading = false
    @State private var isMutating = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var renameDraft: AccountRenameDraft?

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("new-account@chemvault.science", text: $newEmail)
                    Button {
                        addAccount()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .disabled(!canAddAccount)
                }
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .foregroundStyle(.green)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section("Accounts") {
                ForEach(accounts) { account in
                    AccountRowView(
                        account: account,
                        isPrimary: isPrimary(account),
                        isBusy: isMutating,
                        rename: { beginRename(account) },
                        toggleAllReceive: { mutate { try await toggleAllReceive(account) } },
                        pin: { mutate { try await pin(account) } },
                        delete: { mutate { try await delete(account) } }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !isPrimary(account) {
                            Button(role: .destructive) {
                                mutate { try await delete(account) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            mutate { try await toggleAllReceive(account) }
                        } label: {
                            Label(account.allReceive == 1 ? "Disable All" : "Receive All", systemImage: "tray.and.arrow.down")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .overlay {
            if isLoading && accounts.isEmpty {
                ProgressView()
            } else if !isLoading && accounts.isEmpty && errorMessage == nil {
                ContentUnavailableView("Accounts", systemImage: "person.crop.circle.badge.plus", description: Text("Add an email account to start receiving mail."))
            } else if isMutating {
                ProgressView()
            }
        }
        .navigationTitle("Accounts")
        .toolbar {
            Button {
                Task { await load() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(isLoading || isMutating)
        }
        .sheet(item: $renameDraft) { draft in
            AccountRenameSheet(draft: draft) { name in
                try await rename(draft.account, name: name)
            }
        }
        .task { await load() }
    }

    private var canAddAccount: Bool {
        newEmail.nilIfBlank != nil && !isMutating
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            accounts = try await appEnvironment.apiClient.accounts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func isPrimary(_ account: ChemVaultAccount) -> Bool {
        if authSession.currentUser?.account?.accountId == account.accountId {
            return true
        }
        return authSession.currentUser?.email.caseInsensitiveCompare(account.email) == .orderedSame
    }

    private func addAccount() {
        guard let email = newEmail.nilIfBlank else { return }
        Task {
            isMutating = true
            errorMessage = nil
            statusMessage = nil
            do {
                let account = try await appEnvironment.apiClient.addAccount(email: email)
                accounts.insert(account, at: 0)
                newEmail = ""
                statusMessage = "Account added."
            } catch {
                errorMessage = error.localizedDescription
            }
            isMutating = false
        }
    }

    private func beginRename(_ account: ChemVaultAccount) {
        renameDraft = AccountRenameDraft(account: account, name: account.displayName)
    }

    private func mutate(_ operation: @escaping () async throws -> Void) {
        Task {
            isMutating = true
            errorMessage = nil
            statusMessage = nil
            do {
                try await operation()
            } catch {
                errorMessage = error.localizedDescription
            }
            isMutating = false
        }
    }

    private func rename(_ account: ChemVaultAccount, name: String) async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try await appEnvironment.apiClient.setAccountName(accountId: account.accountId, name: trimmedName)
        update(account.accountId) { $0.name = trimmedName }
        statusMessage = "Account renamed."
    }

    private func toggleAllReceive(_ account: ChemVaultAccount) async throws {
        let willEnable = account.allReceive != 1
        try await appEnvironment.apiClient.setAccountAllReceive(accountId: account.accountId)
        for index in accounts.indices {
            accounts[index].allReceive = 0
        }
        update(account.accountId) { $0.allReceive = willEnable ? 1 : 0 }
        statusMessage = willEnable ? "All mail will route to \(account.displayName)." : "All mail routing disabled."
    }

    private func pin(_ account: ChemVaultAccount) async throws {
        try await appEnvironment.apiClient.setAccountAsTop(accountId: account.accountId)
        if let index = accounts.firstIndex(where: { $0.accountId == account.accountId }) {
            let movedAccount = accounts.remove(at: index)
            accounts.insert(movedAccount, at: 0)
        }
        statusMessage = "Account pinned."
    }

    private func delete(_ account: ChemVaultAccount) async throws {
        try await appEnvironment.apiClient.deleteAccount(accountId: account.accountId)
        accounts.removeAll { $0.accountId == account.accountId }
        statusMessage = "Account deleted."
    }

    private func update(_ accountId: Int, mutate: (inout ChemVaultAccount) -> Void) {
        guard let index = accounts.firstIndex(where: { $0.accountId == accountId }) else { return }
        mutate(&accounts[index])
    }
}

private struct AccountRowView: View {
    var account: ChemVaultAccount
    var isPrimary: Bool
    var isBusy: Bool
    var rename: () -> Void
    var toggleAllReceive: () -> Void
    var pin: () -> Void
    var delete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: account.allReceive == 1 ? "tray.and.arrow.down.fill" : "envelope.circle.fill")
                .font(.title2)
                .foregroundStyle(account.allReceive == 1 ? .blue : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(account.displayName)
                        .font(.headline)
                    if isPrimary {
                        Label("Primary", systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if account.allReceive == 1 {
                        Label("All", systemImage: "tray.and.arrow.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(account.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let latestEmailTime = account.latestEmailTime {
                    Label(latestEmailTime, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Menu {
                Button {
                    rename()
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Button {
                    toggleAllReceive()
                } label: {
                    Label(account.allReceive == 1 ? "Disable All Mail" : "Receive All Mail", systemImage: "tray.and.arrow.down")
                }

                if !isPrimary {
                    Button {
                        pin()
                    } label: {
                        Label("Pin to Top", systemImage: "pin")
                    }

                    Button(role: .destructive) {
                        delete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            } label: {
                Label("Account Actions", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .disabled(isBusy)
        }
        .padding(.vertical, 4)
    }
}

private struct AccountRenameDraft: Identifiable {
    var account: ChemVaultAccount
    var name: String

    var id: Int { account.accountId }
}

private struct AccountRenameSheet: View {
    @Environment(\.dismiss) private var dismiss

    var account: ChemVaultAccount
    var save: (String) async throws -> Void

    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(draft: AccountRenameDraft, save: @escaping (String) async throws -> Void) {
        self.account = draft.account
        self.save = save
        self._name = State(initialValue: draft.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display name", text: $name)
                    LabeledContent("Email", value: account.email)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Rename Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveName() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !isSaving && !trimmedName.isEmpty && trimmedName.count <= 30
    }

    private func saveName() async {
        isSaving = true
        errorMessage = nil
        do {
            try await save(name)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
