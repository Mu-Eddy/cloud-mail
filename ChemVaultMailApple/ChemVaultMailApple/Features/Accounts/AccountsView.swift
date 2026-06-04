import SwiftUI

struct AccountsView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @State private var accounts: [ChemVaultAccount] = []
    @State private var newEmail = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                    .disabled(newEmail.isEmpty)
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
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(account.displayName)
                                .font(.headline)
                            Spacer()
                            if account.allReceive == 1 {
                                Label("All", systemImage: "tray.and.arrow.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(account.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            delete(account)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .overlay {
            if isLoading && accounts.isEmpty {
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
        }
        .task { await load() }
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

    private func addAccount() {
        let email = newEmail
        Task {
            do {
                let account: ChemVaultAccount = try await appEnvironment.apiClient.post("/account/add", body: AccountAddRequest(email: email, token: nil))
                accounts.insert(account, at: 0)
                newEmail = ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func delete(_ account: ChemVaultAccount) {
        Task {
            do {
                let _: EmptyResponse = try await appEnvironment.apiClient.delete(
                    "/account/delete",
                    query: [URLQueryItem(name: "accountId", value: String(account.accountId))]
                )
                accounts.removeAll { $0.accountId == account.accountId }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
