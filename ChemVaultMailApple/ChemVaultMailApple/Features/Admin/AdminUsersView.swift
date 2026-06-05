import Foundation
import SwiftUI

struct AdminUsersView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @State private var users: [AdminUserRow] = []
    @State private var roles: [ChemVaultRole] = []
    @State private var total: Int?
    @State private var isLoading = false
    @State private var isMutating = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var roleDraft: AdminUserRoleDraft?
    @State private var passwordDraft: AdminUserPasswordDraft?

    var body: some View {
        List {
            if let total {
                Section {
                    LabeledContent("Total users", value: String(total))
                }
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .foregroundStyle(.green)
                }
            }

            ForEach(users) { user in
                AdminUserRowView(
                    user: user,
                    roleName: roleName(for: user),
                    isBusy: isMutating,
                    toggleStatus: { mutate { try await toggleStatus(user) } },
                    changeRole: { beginRoleChange(user) },
                    resetPassword: { beginPasswordReset(user) },
                    resetSendCount: { mutate { try await resetSendCount(user) } }
                )
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .overlay {
            if isLoading || isMutating {
                ProgressView()
            } else if users.isEmpty && errorMessage == nil {
                ContentUnavailableView("Users", systemImage: "person.2", description: Text("No users loaded."))
            }
        }
        .navigationTitle("Users")
        .toolbar {
            Button {
                Task { await load() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(isLoading || isMutating)
        }
        .sheet(item: $roleDraft) { draft in
            AdminUserRoleSheet(draft: draft, roles: roles) { roleId in
                try await setRole(draft.user, roleId: roleId)
            }
        }
        .sheet(item: $passwordDraft) { draft in
            AdminUserPasswordSheet(draft: draft) { password in
                try await resetPassword(draft.user, password: password)
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        do {
            let response: PagedListResponse<AdminUserRow> = try await appEnvironment.apiClient.get(
                "/user/list",
                query: [
                    URLQueryItem(name: "num", value: "1"),
                    URLQueryItem(name: "size", value: "30"),
                    URLQueryItem(name: "status", value: "-1"),
                    URLQueryItem(name: "timeSort", value: "0"),
                    URLQueryItem(name: "isDel", value: "0")
                ]
            )
            let roles: [ChemVaultRole] = try await appEnvironment.apiClient.get("/role/list")
            users = response.list
            total = response.total
            self.roles = roles
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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

    private func roleName(for user: AdminUserRow) -> String {
        if user.type == 0 {
            return "Admin"
        }
        guard let type = user.type else {
            return "No role"
        }
        return roles.first(where: { $0.roleId == type })?.name ?? "Role \(type)"
    }

    private func beginRoleChange(_ user: AdminUserRow) {
        roleDraft = AdminUserRoleDraft(user: user, roleId: user.type ?? roles.first?.roleId ?? 0)
    }

    private func beginPasswordReset(_ user: AdminUserRow) {
        passwordDraft = AdminUserPasswordDraft(user: user)
    }

    private func toggleStatus(_ user: AdminUserRow) async throws {
        let nextStatus = user.status == 1 ? 0 : 1
        try await appEnvironment.apiClient.setAdminUserStatus(userId: user.userId, status: nextStatus)
        update(user.userId) { $0.status = nextStatus }
        statusMessage = nextStatus == 1 ? "User disabled." : "User enabled."
    }

    private func setRole(_ user: AdminUserRow, roleId: Int) async throws {
        try await appEnvironment.apiClient.setAdminUserType(userId: user.userId, type: roleId)
        update(user.userId) { $0.type = roleId }
        statusMessage = "Role updated."
    }

    private func resetPassword(_ user: AdminUserRow, password: String) async throws {
        try await appEnvironment.apiClient.setAdminUserPassword(userId: user.userId, password: password)
        statusMessage = "Password updated."
    }

    private func resetSendCount(_ user: AdminUserRow) async throws {
        try await appEnvironment.apiClient.resetAdminUserSendCount(userId: user.userId)
        statusMessage = "Send count reset."
    }

    private func update(_ userId: Int, mutate: (inout AdminUserRow) -> Void) {
        guard let index = users.firstIndex(where: { $0.userId == userId }) else { return }
        mutate(&users[index])
    }
}

private struct AdminUserRowView: View {
    var user: AdminUserRow
    var roleName: String
    var isBusy: Bool
    var toggleStatus: () -> Void
    var changeRole: () -> Void
    var resetPassword: () -> Void
    var resetSendCount: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: user.status == 1 ? "person.crop.circle.badge.xmark" : "person.crop.circle")
                .font(.title2)
                .foregroundStyle(user.status == 1 ? .red : .blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(user.displayName)
                        .font(.headline)
                    Spacer()
                    Text(user.statusLabel)
                        .font(.caption)
                        .foregroundStyle(user.status == 1 ? .red : .secondary)
                }
                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Label(roleName, systemImage: "key.horizontal")
                    Label("\(user.accountCount ?? 0)", systemImage: "person.2")
                    Label("\(user.receiveEmailCount ?? 0)", systemImage: "tray.and.arrow.down")
                    Label("\(user.sendEmailCount ?? 0)", systemImage: "paperplane")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Menu {
                Button {
                    toggleStatus()
                } label: {
                    Label(user.status == 1 ? "Enable User" : "Disable User", systemImage: user.status == 1 ? "checkmark.circle" : "nosign")
                }

                if user.type != 0 {
                    Button {
                        changeRole()
                    } label: {
                        Label("Change Role", systemImage: "key.horizontal")
                    }
                }

                Button {
                    resetPassword()
                } label: {
                    Label("Reset Password", systemImage: "lock.rotation")
                }

                Button {
                    resetSendCount()
                } label: {
                    Label("Reset Send Count", systemImage: "arrow.counterclockwise")
                }
            } label: {
                Label("User Actions", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .disabled(isBusy)
        }
        .padding(.vertical, 4)
    }
}

private struct AdminUserRoleDraft: Identifiable {
    var user: AdminUserRow
    var roleId: Int

    var id: Int { user.userId }
}

private struct AdminUserRoleSheet: View {
    @Environment(\.dismiss) private var dismiss

    var user: AdminUserRow
    var roles: [ChemVaultRole]
    var save: (Int) async throws -> Void

    @State private var roleId: Int
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(draft: AdminUserRoleDraft, roles: [ChemVaultRole], save: @escaping (Int) async throws -> Void) {
        self.user = draft.user
        self.roles = roles
        self.save = save
        self._roleId = State(initialValue: draft.roleId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("User", value: user.email)
                    Picker("Role", selection: $roleId) {
                        ForEach(roles) { role in
                            Text(role.name).tag(role.roleId)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Change Role")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveRole() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving || roles.isEmpty || roleId == 0)
                }
            }
        }
    }

    private func saveRole() async {
        isSaving = true
        errorMessage = nil
        do {
            try await save(roleId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

private struct AdminUserPasswordDraft: Identifiable {
    var user: AdminUserRow

    var id: Int { user.userId }
}

private struct AdminUserPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss

    var user: AdminUserRow
    var save: (String) async throws -> Void

    @State private var password = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(draft: AdminUserPasswordDraft, save: @escaping (String) async throws -> Void) {
        self.user = draft.user
        self.save = save
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("User", value: user.email)
                    SecureField("New password", text: $password)
                    Text("Password must be at least 6 characters.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Reset Password")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await savePassword() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving || password.count < 6)
                }
            }
        }
    }

    private func savePassword() async {
        isSaving = true
        errorMessage = nil
        do {
            try await save(password)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
