import Combine
import Foundation

enum MailboxMode: String {
    case inbox
    case starred

    var title: String {
        switch self {
        case .inbox: return "Inbox"
        case .starred: return "Starred"
        }
    }
}

@MainActor
final class MailStore: ObservableObject {
    @Published var emails: [ChemVaultEmail] = []
    @Published var selectedEmail: ChemVaultEmail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var total: Int?
    @Published var latestEmail: ChemVaultEmail?

    func load(mode: MailboxMode, apiClient: APIClient) async {
        isLoading = true
        errorMessage = nil
        do {
            let response: MailListResponse
            switch mode {
            case .inbox:
                response = try await apiClient.inbox()
            case .starred:
                response = try await apiClient.starred()
            }
            emails = response.list
            total = response.total
            latestEmail = response.latestEmail
            if selectedEmail == nil {
                selectedEmail = emails.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteSelected(apiClient: APIClient) async {
        guard let selectedEmail else { return }
        do {
            try await apiClient.deleteEmails([selectedEmail.emailId])
            emails.removeAll { $0.emailId == selectedEmail.emailId }
            self.selectedEmail = emails.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markSelectedRead(apiClient: APIClient) async {
        guard let selectedEmail else { return }
        do {
            try await apiClient.markRead(emailIds: [selectedEmail.emailId])
            updateSelected { email in
                email.unread = 1
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleStar(apiClient: APIClient) async {
        guard let selectedEmail else { return }
        do {
            if selectedEmail.starred {
                try await apiClient.cancelStar(emailId: selectedEmail.emailId)
                updateSelected { email in
                    email.isStar = 0
                    email.starId = nil
                }
            } else {
                try await apiClient.addStar(emailId: selectedEmail.emailId)
                updateSelected { email in
                    email.isStar = 1
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateSelected(_ mutate: (inout ChemVaultEmail) -> Void) {
        guard let selectedEmail, let index = emails.firstIndex(where: { $0.emailId == selectedEmail.emailId }) else {
            return
        }
        mutate(&emails[index])
        self.selectedEmail = emails[index]
    }
}

