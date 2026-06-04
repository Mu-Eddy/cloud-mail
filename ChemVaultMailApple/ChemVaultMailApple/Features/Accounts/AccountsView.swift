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
    @State private var avatarDraft: AccountAvatarDraft?

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
                        setAvatar: { beginAvatar(account) },
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
        .sheet(item: $avatarDraft) { draft in
            AccountAvatarSheet(draft: draft) { avatarType, avatar in
                try await saveAvatar(draft.account, avatarType: avatarType, avatar: avatar)
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

    private func beginAvatar(_ account: ChemVaultAccount) {
        avatarDraft = AccountAvatarDraft(account: account)
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

    private func saveAvatar(_ account: ChemVaultAccount, avatarType: AccountAvatarType, avatar: String) async throws {
        let response = try await appEnvironment.apiClient.setAccountAvatar(
            accountId: account.accountId,
            avatarType: avatarType,
            avatar: avatar
        )
        update(account.accountId) { account in
            account.avatarType = response.avatarType.rawValue
            account.avatar = response.avatar
        }
        if isPrimary(account) {
            await authSession.refreshUser()
        }
        statusMessage = "Avatar updated."
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
    var setAvatar: () -> Void
    var toggleAllReceive: () -> Void
    var pin: () -> Void
    var delete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            AccountAvatarBadge(account: account, size: 38)

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
                    setAvatar()
                } label: {
                    Label("Set Avatar", systemImage: "person.crop.circle")
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

private struct AccountAvatarDraft: Identifiable {
    var account: ChemVaultAccount
    var avatarType: AccountAvatarType
    var avatarURL: String

    init(account: ChemVaultAccount) {
        self.account = account
        self.avatarType = AccountAvatarType(rawValue: account.avatarType ?? "") ?? .initial
        self.avatarURL = account.avatar?.hasHTTPPrefix == true ? account.avatar ?? "" : ""
    }

    var id: Int { account.accountId }
}

private struct AccountAvatarSheet: View {
    @Environment(\.dismiss) private var dismiss

    var account: ChemVaultAccount
    var save: (AccountAvatarType, String) async throws -> Void

    @State private var avatarType: AccountAvatarType
    @State private var avatarURL: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(draft: AccountAvatarDraft, save: @escaping (AccountAvatarType, String) async throws -> Void) {
        self.account = draft.account
        self.save = save
        self._avatarType = State(initialValue: draft.avatarType)
        self._avatarURL = State(initialValue: draft.avatarURL)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        AccountAvatarBadge(account: account, avatarType: avatarType, avatar: avatarURL, size: 84)
                        Spacer()
                    }
                    .padding(.vertical, 8)

                    Picker("Style", selection: $avatarType) {
                        ForEach(AccountAvatarType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if avatarType == .custom {
                    Section("Custom Image") {
                        TextField("https://img.example/avatar.png", text: $avatarURL)
                            .autocorrectionDisabled()
                        Text("Use a direct http or https image URL. Local photo upload can be added in a later pass.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Set Avatar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveAvatar() }
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

    private var trimmedAvatarURL: String {
        avatarURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        if isSaving { return false }
        guard avatarType == .custom else { return true }
        return trimmedAvatarURL.hasHTTPPrefix
    }

    private func saveAvatar() async {
        isSaving = true
        errorMessage = nil
        do {
            let avatar = avatarType == .custom ? trimmedAvatarURL : ""
            try await save(avatarType, avatar)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

private struct AccountAvatarBadge: View {
    var account: ChemVaultAccount
    var avatarType: AccountAvatarType?
    var avatar: String?
    var size: CGFloat

    var body: some View {
        Group {
            switch resolvedAvatarType {
            case .initial:
                Circle()
                    .fill(.blue.opacity(0.16))
                    .overlay {
                        Text(initial)
                            .font(.system(size: size * 0.42, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
            case .logo:
                Circle()
                    .fill(.indigo.opacity(0.16))
                    .overlay {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: size * 0.4, weight: .semibold))
                            .foregroundStyle(.indigo)
                    }
            case .custom:
                customAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel("Account avatar")
    }

    @ViewBuilder
    private var customAvatar: some View {
        if let url = customURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallbackCustomAvatar
                case .empty:
                    ProgressView()
                @unknown default:
                    fallbackCustomAvatar
                }
            }
        } else {
            fallbackCustomAvatar
        }
    }

    private var fallbackCustomAvatar: some View {
        Circle()
            .fill(.secondary.opacity(0.14))
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
    }

    private var resolvedAvatarType: AccountAvatarType {
        avatarType ?? AccountAvatarType(rawValue: account.avatarType ?? "") ?? .initial
    }

    private var customURL: URL? {
        let value = (avatar ?? account.avatar ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasHTTPPrefix else { return nil }
        return URL(string: value)
    }

    private var initial: String {
        let source = account.displayName.isEmpty ? account.email : account.displayName
        let name = source.split(separator: "@").first.map(String.init) ?? source
        return String(name.prefix(1)).uppercased()
    }
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

private extension String {
    var hasHTTPPrefix: Bool {
        lowercased().hasPrefix("http://") || lowercased().hasPrefix("https://")
    }
}
