import Foundation
import SwiftUI

struct AdminUsersView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @State private var users: [AdminUserRow] = []
    @State private var roles: [ChemVaultRole] = []
    @State private var domainList: [String] = []
    @State private var total = 0
    @State private var page = 1
    @State private var pageSize = 15
    @State private var emailQuery = ""
    @State private var statusFilter: AdminUserStatusFilter = .all
    @State private var timeSort = 0
    @State private var isLoading = false
    @State private var isMutating = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var roleDraft: AdminUserRoleDraft?
    @State private var passwordDraft: AdminUserPasswordDraft?
    @State private var addDraft: AdminUserAddDraft?
    @State private var confirmation: AdminUserConfirmation?

    private let pageSizes = [10, 15, 20, 25, 30, 50]

    var body: some View {
        ZStack {
            AdminStyle.pageBackground
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 12) {
                    headerContent
                    messageContent
                    userListContent
                    footerContent
                }
                .padding()
            }
            .refreshable {
                await load()
            }

            if isMutating {
                AdminBlockingProgressView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: users)
        .animation(.easeInOut(duration: 0.2), value: statusMessage)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
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
        .sheet(item: $addDraft) { draft in
            AdminUserAddSheet(draft: draft, roles: roles, domains: domainList) { email, password, roleId in
                try await addUser(email: email, password: password, roleId: roleId)
            }
        }
        .confirmationDialog(
            confirmation?.title ?? "",
            isPresented: Binding(
                get: { confirmation != nil },
                set: { isPresented in
                    if !isPresented {
                        confirmation = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let confirmation {
                switch confirmation.action {
                case .delete:
                    Button("Delete User", role: .destructive) {
                        mutate { try await deleteUser(confirmation.user) }
                    }
                case .restore:
                    Button("Restore User") {
                        mutate { try await restoreUser(confirmation.user) }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmation?.message ?? "")
        }
        .task { await load() }
        .onChange(of: statusFilter) {
            page = 1
            Task { await load() }
        }
        .onChange(of: pageSize) {
            page = 1
            Task { await load() }
        }
    }

    private var maxPage: Int {
        max(1, Int(ceil(Double(total) / Double(pageSize))))
    }

    private var headerContent: some View {
        Group {
            AdminUsersToolbar(
                emailQuery: $emailQuery,
                statusFilter: $statusFilter,
                pageSize: $pageSize,
                pageSizes: pageSizes,
                timeSort: timeSort,
                isBusy: isLoading || isMutating,
                search: search,
                reset: resetFilters,
                toggleSort: toggleSort,
                addUser: beginAddUser
            )

            AdminUsersSummaryCard(
                total: total,
                showing: users.count,
                page: page,
                maxPage: maxPage,
                filter: statusFilter,
                isLoading: isLoading
            )
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        if let statusMessage {
            AdminNoticeBanner(message: statusMessage, tone: .success)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }

        if let errorMessage {
            AdminNoticeBanner(message: errorMessage, tone: .danger)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private var userListContent: some View {
        if isLoading && users.isEmpty {
            AdminLoadingCard()
                .transition(.opacity)
        } else if users.isEmpty && errorMessage == nil {
            ContentUnavailableView("Users", systemImage: "person.2", description: Text("No users match the current filters."))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .background(AdminStyle.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            ForEach(users) { user in
                userCard(user)
            }
        }
    }

    private var footerContent: some View {
        AdminUsersPagination(
            page: page,
            maxPage: maxPage,
            total: total,
            isBusy: isLoading || isMutating,
            previous: previousPage,
            next: nextPage
        )
    }

    private func userCard(_ user: AdminUserRow) -> some View {
        AdminUserCard(
            user: user,
            roleName: roleName(for: user),
            isBusy: isMutating,
            toggleStatus: { mutate { try await toggleStatus(user) } },
            changeRole: { beginRoleChange(user) },
            resetPassword: { beginPasswordReset(user) },
            resetSendCount: { mutate { try await resetSendCount(user) } },
            deleteUser: { confirm(.delete, user: user) },
            restoreUser: { confirm(.restore, user: user) }
        )
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: PagedListResponse<AdminUserRow> = try await appEnvironment.apiClient.get(
                "/user/list",
                query: userListQueryItems()
            )
            let fetchedRoles: [ChemVaultRole] = try await appEnvironment.apiClient.get("/role/list")
            let setting: ChemVaultSetting = try await appEnvironment.apiClient.get("/setting/websiteConfig")

            withAnimation(.easeInOut(duration: 0.2)) {
                users = response.list
                total = response.total ?? response.list.count
                roles = fetchedRoles
                domainList = setting.domainList ?? []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func userListQueryItems() -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "num", value: String(page)),
            URLQueryItem(name: "size", value: String(pageSize)),
            URLQueryItem(name: "timeSort", value: String(timeSort))
        ]

        if statusFilter == .deleted {
            items.append(URLQueryItem(name: "isDel", value: "1"))
        } else {
            items.append(URLQueryItem(name: "status", value: String(statusFilter.statusValue)))
            items.append(URLQueryItem(name: "isDel", value: "0"))
        }

        if let email = emailQuery.nilIfBlank {
            items.append(URLQueryItem(name: "email", value: email))
        }

        return items
    }

    private func search() {
        page = 1
        Task { await load() }
    }

    private func resetFilters() {
        emailQuery = ""
        statusFilter = .all
        timeSort = 0
        page = 1
        Task { await load() }
    }

    private func toggleSort() {
        timeSort = timeSort == 0 ? 1 : 0
        page = 1
        Task { await load() }
    }

    private func previousPage() {
        guard page > 1 else { return }
        page -= 1
        Task { await load() }
    }

    private func nextPage() {
        guard page < maxPage else { return }
        page += 1
        Task { await load() }
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

    private func beginAddUser() {
        addDraft = AdminUserAddDraft(defaultRoleId: roles.first?.roleId ?? 0)
    }

    private func confirm(_ action: AdminUserConfirmation.Action, user: AdminUserRow) {
        confirmation = AdminUserConfirmation(action: action, user: user)
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
        update(user.userId) { $0.sendCount = 0 }
        statusMessage = "Send count reset."
    }

    private func addUser(email: String, password: String, roleId: Int) async throws {
        try await appEnvironment.apiClient.addAdminUser(email: email, password: password, type: roleId)
        statusMessage = "User added."
        page = 1
        await load()
    }

    private func deleteUser(_ user: AdminUserRow) async throws {
        try await appEnvironment.apiClient.deleteAdminUsers([user.userId])
        statusMessage = "User deleted."
        await load()
    }

    private func restoreUser(_ user: AdminUserRow) async throws {
        try await appEnvironment.apiClient.restoreAdminUser(userId: user.userId)
        update(user.userId) { row in
            row.isDel = 0
            row.status = 0
        }
        statusMessage = "User restored."
        if statusFilter == .deleted {
            await load()
        }
    }

    private func update(_ userId: Int, mutate: (inout AdminUserRow) -> Void) {
        guard let index = users.firstIndex(where: { $0.userId == userId }) else { return }
        mutate(&users[index])
    }
}

private struct AdminUsersToolbar: View {
    @Binding var emailQuery: String
    @Binding var statusFilter: AdminUserStatusFilter
    @Binding var pageSize: Int
    var pageSizes: [Int]
    var timeSort: Int
    var isBusy: Bool
    var search: () -> Void
    var reset: () -> Void
    var toggleSort: () -> Void
    var addUser: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search by email", text: $emailQuery)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onSubmit(search)
                if emailQuery.nilIfBlank != nil {
                    Button {
                        emailQuery = ""
                        search()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(AdminStyle.inputBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    controls
                }
                VStack(alignment: .leading, spacing: 10) {
                    controls
                }
            }
        }
        .padding(12)
        .background(AdminStyle.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AdminStyle.borderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private var controls: some View {
        Group {
            Picker("Status", selection: $statusFilter) {
                ForEach(AdminUserStatusFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.systemImage).tag(filter)
                }
            }
            .labelsHidden()
            .controlSize(.small)

            Picker("Page Size", selection: $pageSize) {
                ForEach(pageSizes, id: \.self) { size in
                    Text("\(size) / page").tag(size)
                }
            }
            .labelsHidden()
            .controlSize(.small)

            Button(action: toggleSort) {
                Label(timeSort == 0 ? "Newest" : "Oldest", systemImage: timeSort == 0 ? "timer" : "timer.circle")
            }
            .buttonStyle(AdminPillButtonStyle(tint: .secondary))

            Button(action: search) {
                Label("Search", systemImage: "magnifyingglass")
            }
            .buttonStyle(AdminPillButtonStyle(tint: AdminStyle.primary))
            .disabled(isBusy)

            Button(action: reset) {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(AdminPillButtonStyle(tint: .secondary))
            .disabled(isBusy)

            Button(action: addUser) {
                Label("Add User", systemImage: "plus")
            }
            .buttonStyle(AdminPillButtonStyle(tint: AdminStyle.primary))
            .disabled(isBusy)
        }
    }
}

private struct AdminUsersSummaryCard: View {
    var total: Int
    var showing: Int
    var page: Int
    var maxPage: Int
    var filter: AdminUserStatusFilter
    var isLoading: Bool

    var body: some View {
        HStack(spacing: 14) {
            AdminMetricBlock(title: "Total", value: "\(total)", systemImage: "person.2.fill")
            Divider()
            AdminMetricBlock(title: "Showing", value: "\(showing)", systemImage: "list.bullet.rectangle")
            Divider()
            AdminMetricBlock(title: "Page", value: "\(page)/\(maxPage)", systemImage: "rectangle.stack")
            Spacer(minLength: 8)
            AdminStatusChip(title: filter.title, systemImage: filter.systemImage, tone: filter.tone)
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(AdminStyle.primaryLight, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AdminStyle.primary.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct AdminMetricBlock: View {
    var title: String
    var value: String
    var systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(AdminStyle.primary)
        }
    }
}

private struct AdminUserCard: View {
    var user: AdminUserRow
    var roleName: String
    var isBusy: Bool
    var toggleStatus: () -> Void
    var changeRole: () -> Void
    var resetPassword: () -> Void
    var resetSendCount: () -> Void
    var deleteUser: () -> Void
    var restoreUser: () -> Void

    private var isDeleted: Bool {
        user.isDel == 1
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(statusTone.lightColor)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(initial)
                            .font(.headline)
                            .foregroundStyle(statusTone.color)
                    }

                Image(systemName: isDeleted ? "trash.circle.fill" : user.status == 1 ? "nosign" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(statusTone.color)
                    .background(AdminStyle.cardBackground, in: Circle())
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(user.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    if user.username?.nilIfBlank != nil {
                        AdminStatusChip(title: "L", systemImage: "link", tone: .warning)
                    }
                    Spacer(minLength: 8)
                    AdminStatusChip(title: displayStatus, systemImage: statusSystemImage, tone: statusTone)
                }

                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        AdminStatusChip(title: roleName, systemImage: "key.horizontal", tone: .info)
                        AdminStatusChip(title: "\(user.accountCount ?? 0)", systemImage: "person.2", tone: .neutral)
                        AdminStatusChip(title: "\(user.receiveEmailCount ?? 0)", systemImage: "tray.and.arrow.down", tone: .neutral)
                        AdminStatusChip(title: "\(user.sendEmailCount ?? 0)", systemImage: "paperplane", tone: .neutral)
                    }
                }

                if let createTime = user.createTime {
                    Label(createTime, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Menu {
                if isDeleted {
                    Button {
                        restoreUser()
                    } label: {
                        Label("Restore User", systemImage: "arrow.uturn.backward.circle")
                    }
                } else {
                    if user.type != 0 {
                        Button {
                            toggleStatus()
                        } label: {
                            Label(user.status == 1 ? "Enable User" : "Disable User", systemImage: user.status == 1 ? "checkmark.circle" : "nosign")
                        }

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

                    if user.type != 0 {
                        Button(role: .destructive) {
                            deleteUser()
                        } label: {
                            Label("Delete User", systemImage: "trash")
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(AdminStyle.primary)
                    .frame(width: 30, height: 30)
            }
            .disabled(isBusy)
        }
        .padding(14)
        .background(AdminStyle.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isDeleted ? Color.secondary.opacity(0.18) : AdminStyle.borderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.035), radius: 8, x: 0, y: 3)
        .opacity(isDeleted ? 0.72 : 1)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isDeleted {
                Button {
                    restoreUser()
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.backward.circle")
                }
                .tint(.green)
            } else if user.type != 0 {
                Button(role: .destructive) {
                    deleteUser()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if !isDeleted && user.type != 0 {
                Button {
                    toggleStatus()
                } label: {
                    Label(user.status == 1 ? "Enable" : "Disable", systemImage: user.status == 1 ? "checkmark.circle" : "nosign")
                }
                .tint(user.status == 1 ? .green : .red)
            }
        }
    }

    private var initial: String {
        let name = user.displayName.split(separator: "@").first.map(String.init) ?? user.displayName
        return String(name.prefix(1)).uppercased()
    }

    private var displayStatus: String {
        if isDeleted {
            return "Deleted"
        }
        return user.statusLabel
    }

    private var statusSystemImage: String {
        if isDeleted {
            return "trash"
        }
        return user.status == 1 ? "nosign" : "checkmark.circle"
    }

    private var statusTone: AdminTone {
        if isDeleted {
            return .neutral
        }
        return user.status == 1 ? .danger : .success
    }
}

private struct AdminUsersPagination: View {
    var page: Int
    var maxPage: Int
    var total: Int
    var isBusy: Bool
    var previous: () -> Void
    var next: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(total) users")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: previous) {
                Image(systemName: "chevron.left")
            }
            .disabled(isBusy || page <= 1)
            Text("\(page) / \(maxPage)")
                .font(.caption)
                .monospacedDigit()
                .frame(minWidth: 56)
            Button(action: next) {
                Image(systemName: "chevron.right")
            }
            .disabled(isBusy || page >= maxPage)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
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

private struct AdminUserAddDraft: Identifiable {
    var id = UUID()
    var defaultRoleId: Int
}

private struct AdminUserAddSheet: View {
    @Environment(\.dismiss) private var dismiss

    var roles: [ChemVaultRole]
    var domains: [String]
    var save: (String, String, Int) async throws -> Void

    @State private var localPart = ""
    @State private var fullEmail = ""
    @State private var suffix: String
    @State private var password = ""
    @State private var roleId: Int
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(draft: AdminUserAddDraft, roles: [ChemVaultRole], domains: [String], save: @escaping (String, String, Int) async throws -> Void) {
        self.roles = roles
        self.domains = domains
        self.save = save
        self._suffix = State(initialValue: domains.first ?? "")
        self._roleId = State(initialValue: draft.defaultRoleId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if domains.isEmpty {
                        TextField("user@chemvault.science", text: $fullEmail)
                            .autocorrectionDisabled()
                    } else {
                        HStack {
                            TextField("user", text: $localPart)
                                .autocorrectionDisabled()
                            Picker("Domain", selection: $suffix) {
                                ForEach(domains, id: \.self) { domain in
                                    Text(domain).tag(domain)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    SecureField("Password", text: $password)
                    Picker("Role", selection: $roleId) {
                        ForEach(roles) { role in
                            Text(role.name).tag(role.roleId)
                        }
                    }
                }

                Section {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(AdminStyle.primary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(emailPreview)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text("The user will be created with the selected role.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
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
            .navigationTitle("Add User")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveUser() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var emailPreview: String {
        if domains.isEmpty {
            return fullEmail.nilIfBlank ?? "Email"
        }
        return (localPart.nilIfBlank ?? "user") + suffix
    }

    private var emailValue: String {
        if domains.isEmpty {
            return fullEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return localPart.trimmingCharacters(in: .whitespacesAndNewlines) + suffix
    }

    private var canSave: Bool {
        !isSaving && emailValue.contains("@") && password.count >= 6 && roleId != 0
    }

    private func saveUser() async {
        isSaving = true
        errorMessage = nil
        do {
            try await save(emailValue, password, roleId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

private struct AdminNoticeBanner: View {
    var message: String
    var tone: AdminTone

    var body: some View {
        Label(message, systemImage: tone == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(tone.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(tone.lightColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AdminLoadingCard: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading users...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(AdminStyle.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AdminBlockingProgressView: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Applying changes")
                .font(.subheadline)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(radius: 16)
    }
}

private struct AdminStatusChip: View {
    var title: String
    var systemImage: String
    var tone: AdminTone

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .lineLimit(1)
            .foregroundStyle(tone.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tone.lightColor, in: Capsule())
    }
}

private struct AdminPillButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .lineLimit(1)
            .foregroundStyle(tint == AdminStyle.primary ? .white : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                tint == AdminStyle.primary ? tint.opacity(configuration.isPressed ? 0.82 : 1) : tint.opacity(configuration.isPressed ? 0.18 : 0.1),
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private enum AdminUserStatusFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case disabled
    case deleted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .disabled: return "Disabled"
        case .deleted: return "Deleted"
        }
    }

    var statusValue: Int {
        switch self {
        case .all: return -1
        case .active: return 0
        case .disabled: return 1
        case .deleted: return -1
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "line.3.horizontal.decrease.circle"
        case .active: return "checkmark.circle"
        case .disabled: return "nosign"
        case .deleted: return "trash"
        }
    }

    var tone: AdminTone {
        switch self {
        case .all: return .info
        case .active: return .success
        case .disabled: return .danger
        case .deleted: return .neutral
        }
    }
}

private struct AdminUserConfirmation: Identifiable {
    enum Action {
        case delete
        case restore
    }

    var action: Action
    var user: AdminUserRow

    var id: String {
        "\(action)-\(user.userId)"
    }

    var title: String {
        switch action {
        case .delete: return "Delete User"
        case .restore: return "Restore User"
        }
    }

    var message: String {
        switch action {
        case .delete:
            return "Delete \(user.email)? The account moves to the deleted user list."
        case .restore:
            return "Restore \(user.email) to the active user list?"
        }
    }
}

private enum AdminTone: Equatable {
    case success
    case danger
    case warning
    case info
    case neutral

    var color: Color {
        switch self {
        case .success: return .green
        case .danger: return .red
        case .warning: return .orange
        case .info: return AdminStyle.primary
        case .neutral: return .secondary
        }
    }

    var lightColor: Color {
        switch self {
        case .success: return .green.opacity(0.12)
        case .danger: return .red.opacity(0.12)
        case .warning: return .orange.opacity(0.14)
        case .info: return AdminStyle.primaryLight
        case .neutral: return .secondary.opacity(0.12)
        }
    }
}

private enum AdminStyle {
    static let primary = Color(red: 24 / 255, green: 144 / 255, blue: 1)
    static let primaryLight = Color(red: 230 / 255, green: 247 / 255, blue: 1)
    static let borderColor = Color(red: 228 / 255, green: 231 / 255, blue: 237 / 255)
    static let inputBackground = Color(red: 245 / 255, green: 247 / 255, blue: 250 / 255)

    static var pageBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }

    static var cardBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }
}
