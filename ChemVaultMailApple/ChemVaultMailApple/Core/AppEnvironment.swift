import Combine
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let preferences: AppPreferences
    let apiClient: APIClient
    let authSession: AuthSession

    init(
        preferences: AppPreferences = AppPreferences(),
        tokenStore: TokenStoring = KeychainTokenStore()
    ) {
        self.preferences = preferences
        self.apiClient = APIClient(preferences: preferences)
        self.authSession = AuthSession(apiClient: apiClient, tokenStore: tokenStore)
    }
}

