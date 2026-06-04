import Combine
import Foundation

enum AuthState: Equatable {
    case checking
    case signedOut
    case signedIn
}

@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var state: AuthState = .checking
    @Published private(set) var currentUser: ChemVaultUser?
    @Published var lastError: String?

    private let apiClient: APIClient
    private let tokenStore: TokenStoring
    private var token: String? {
        didSet { apiClient.authToken = token }
    }

    init(apiClient: APIClient, tokenStore: TokenStoring) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
        self.token = tokenStore.readToken()
        self.apiClient.authToken = token
        self.state = token == nil ? .signedOut : .checking
    }

    var isAuthenticated: Bool {
        state == .signedIn
    }

    func bootstrap() async {
        guard token?.isEmpty == false else {
            state = .signedOut
            return
        }

        do {
            currentUser = try await apiClient.currentUser()
            state = .signedIn
        } catch APIError.server(let code, _) where code == 401 {
            signOut(clearServer: false)
        } catch {
            lastError = error.localizedDescription
            state = .signedIn
        }
    }

    func login(email: String, password: String) async {
        lastError = nil
        state = .checking
        do {
            let response = try await apiClient.login(email: email, password: password)
            token = response.token
            try tokenStore.saveToken(response.token)
            currentUser = try await apiClient.currentUser()
            state = .signedIn
        } catch {
            lastError = error.localizedDescription
            state = .signedOut
        }
    }

    func register(email: String, password: String, code: String?) async -> Bool {
        lastError = nil
        do {
            _ = try await apiClient.register(email: email, password: password, code: code)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func refreshUser() async {
        do {
            currentUser = try await apiClient.currentUser()
        } catch APIError.server(let code, _) where code == 401 {
            signOut(clearServer: false)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func signOut(clearServer: Bool = true) {
        if clearServer {
            Task {
                try? await apiClient.logout()
            }
        }
        token = nil
        tokenStore.deleteToken()
        currentUser = nil
        state = .signedOut
    }
}

