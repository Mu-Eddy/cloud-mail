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
        await delete(email: selectedEmail, apiClient: apiClient)
    }

    func delete(email: ChemVaultEmail, apiClient: APIClient) async {
        do {
            try await apiClient.deleteEmails([email.emailId])
            emails.removeAll { $0.emailId == email.emailId }
            if selectedEmail?.emailId == email.emailId {
                selectedEmail = emails.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markSelectedRead(apiClient: APIClient) async {
        guard let selectedEmail else { return }
        await markRead(email: selectedEmail, apiClient: apiClient)
    }

    func markRead(email: ChemVaultEmail, apiClient: APIClient) async {
        await markRead(emailIds: [email.emailId], apiClient: apiClient)
    }

    func markVisibleUnreadRead(apiClient: APIClient) async {
        let emailIds = emails.filter(\.isUnread).map(\.emailId)
        guard !emailIds.isEmpty else { return }
        await markRead(emailIds: emailIds, apiClient: apiClient)
    }

    private func markRead(emailIds: [Int], apiClient: APIClient) async {
        do {
            try await apiClient.markRead(emailIds: emailIds)
            emailIds.forEach { emailId in
                update(emailId: emailId) { $0.unread = ChemVaultEmailReadState.read }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleStar(apiClient: APIClient) async {
        guard let selectedEmail else { return }
        await toggleStar(email: selectedEmail, apiClient: apiClient)
    }

    func toggleStar(email: ChemVaultEmail, apiClient: APIClient) async {
        do {
            if email.starred {
                try await apiClient.cancelStar(emailId: email.emailId)
                update(emailId: email.emailId) { email in
                    email.isStar = 0
                    email.starId = nil
                }
            } else {
                try await apiClient.addStar(emailId: email.emailId)
                update(emailId: email.emailId) { email in
                    email.isStar = 1
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func update(emailId: Int, _ mutate: (inout ChemVaultEmail) -> Void) {
        guard let index = emails.firstIndex(where: { $0.emailId == emailId }) else {
            return
        }
        mutate(&emails[index])
        if selectedEmail?.emailId == emailId {
            selectedEmail = emails[index]
        }
        if var latestEmail, latestEmail.emailId == emailId {
            mutate(&latestEmail)
            self.latestEmail = latestEmail
        }
    }
}
