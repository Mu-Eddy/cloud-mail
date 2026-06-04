import Combine
import Foundation

@MainActor
final class AppPreferences: ObservableObject {
    static let defaultBaseURL = "https://mail.chemvault.science"

    @Published var baseURLString: String {
        didSet { defaults.set(baseURLString, forKey: Keys.baseURLString) }
    }

    @Published var language: String {
        didSet { defaults.set(language, forKey: Keys.language) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.baseURLString = defaults.string(forKey: Keys.baseURLString) ?? Self.defaultBaseURL
        self.language = defaults.string(forKey: Keys.language) ?? Locale.preferredLanguages.first?.components(separatedBy: "-").first ?? "en"
    }

    var baseURL: URL? {
        URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func resetBaseURL() {
        baseURLString = Self.defaultBaseURL
    }

    private enum Keys {
        static let baseURLString = "chemvault.baseURLString"
        static let language = "chemvault.language"
    }
}

