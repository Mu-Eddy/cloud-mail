import SwiftUI

struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @State private var accounts: [ChemVaultAccount] = []
    @State private var selectedAccountId: Int?
    @State private var to = ""
    @State private var cc = ""
    @State private var bcc = ""
    @State private var subject = ""
    @State private var bodyText = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("From") {
                    Picker("Account", selection: $selectedAccountId) {
                        ForEach(accounts) { account in
                            Text(account.displayName).tag(Optional(account.accountId))
                        }
                    }
                }

                Section("Recipients") {
                    TextField("To", text: $to)
                    TextField("Cc", text: $cc)
                    TextField("Bcc", text: $bcc)
                }

                Section("Message") {
                    TextField("Subject", text: $subject)
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 180)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Compose")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        send()
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Text("Send")
                        }
                    }
                    .disabled(selectedAccountId == nil || to.emailList.isEmpty || isSending)
                }
            }
            .task {
                await loadAccounts()
            }
        }
    }

    private func loadAccounts() async {
        do {
            accounts = try await appEnvironment.apiClient.accounts()
            selectedAccountId = selectedAccountId ?? accounts.first?.accountId
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func send() {
        guard let accountId = selectedAccountId else { return }
        isSending = true
        errorMessage = nil
        let html = bodyText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "<p>\($0)</p>" }
            .joined()
        let request = ComposeEmailRequest(
            accountId: accountId,
            name: nil,
            sendType: "send",
            emailId: nil,
            receiveEmail: to.emailList,
            text: bodyText,
            content: html,
            subject: subject,
            attachments: []
        )
        Task {
            do {
                _ = try await appEnvironment.apiClient.sendEmail(request)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}

extension String {
    var emailList: [String] {
        split { character in
            character == "," || character == ";" || character == "\n" || character == " "
        }
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    }
}
