import Combine
import Foundation

@MainActor
final class AppPreferences: ObservableObject {
    static let defaultBaseURL = "https://mail.chemvault.science/api"

    @Published var baseURLString: String {
        didSet { defaults.set(baseURLString, forKey: Keys.baseURLString) }
    }

    @Published var language: String {
        didSet { defaults.set(language, forKey: Keys.language) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedBaseURL = defaults.string(forKey: Keys.baseURLString)
        let resolvedBaseURL = Self.resolveStoredBaseURL(storedBaseURL)
        self.baseURLString = resolvedBaseURL
        if storedBaseURL != resolvedBaseURL {
            defaults.set(resolvedBaseURL, forKey: Keys.baseURLString)
        }
        self.language = defaults.string(forKey: Keys.language) ?? Locale.preferredLanguages.first?.components(separatedBy: "-").first ?? "en"
    }

    var baseURL: URL? {
        URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func resetBaseURL() {
        baseURLString = Self.defaultBaseURL
    }

    private static func resolveStoredBaseURL(_ value: String?) -> String {
        guard let value else { return defaultBaseURL }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).trimmingTrailingSlashes()
        if normalized == "https://mail.chemvault.science" {
            return defaultBaseURL
        }
        return value
    }

    private enum Keys {
        static let baseURLString = "chemvault.baseURLString"
        static let language = "chemvault.language"
    }
}

private extension String {
    func trimmingTrailingSlashes() -> String {
        var value = self
        while value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }
}
