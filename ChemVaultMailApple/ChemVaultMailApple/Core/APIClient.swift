import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

@MainActor
final class APIClient {
    var authToken: String?

    private let preferences: AppPreferences
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(preferences: AppPreferences, session: URLSession = .shared) {
        self.preferences = preferences
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder.chemVault
    }

    func get<Value: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> Value {
        try await request(path, method: .get, query: query, body: Optional<EmptyResponse>.none)
    }

    func post<Body: Encodable, Value: Decodable>(_ path: String, body: Body) async throws -> Value {
        try await request(path, method: .post, body: body)
    }

    func put<Body: Encodable, Value: Decodable>(_ path: String, body: Body) async throws -> Value {
        try await request(path, method: .put, body: body)
    }

    func delete<Value: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> Value {
        try await request(path, method: .delete, query: query, body: Optional<EmptyResponse>.none)
    }

    func rawGet(_ path: String, query: [URLQueryItem] = []) async throws -> JSONValue {
        try await get(path, query: query)
    }

    func login(email: String, password: String) async throws -> LoginResponse {
        try await post("/login", body: LoginRequest(email: email, password: password))
    }

    func register(email: String, password: String, code: String?) async throws -> RegisterResponse {
        try await post("/register", body: RegisterRequest(email: email, password: password, code: code?.nilIfBlank, token: nil))
    }

    func logout() async throws {
        let _: EmptyResponse = try await delete("/logout")
    }

    func currentUser() async throws -> ChemVaultUser {
        try await get("/my/loginUserInfo")
    }

    func accounts(size: Int = 30, lastAccountId: Int = 0, lastSort: Int = 9_999_999_999) async throws -> [ChemVaultAccount] {
        try await get(
            "/account/list",
            query: [
                URLQueryItem(name: "accountId", value: String(lastAccountId)),
                URLQueryItem(name: "size", value: String(size)),
                URLQueryItem(name: "lastSort", value: String(lastSort))
            ]
        )
    }

    func addAccount(email: String, token: String? = nil) async throws -> ChemVaultAccount {
        try await post("/account/add", body: AccountAddRequest(email: email, token: token))
    }

    func setAccountName(accountId: Int, name: String) async throws {
        let _: EmptyResponse = try await put("/account/setName", body: AccountNameRequest(accountId: accountId, name: name))
    }

    func setAccountAllReceive(accountId: Int) async throws {
        let _: EmptyResponse = try await put("/account/setAllReceive", body: AccountIdRequest(accountId: accountId))
    }

    func setAccountAsTop(accountId: Int) async throws {
        let _: EmptyResponse = try await put("/account/setAsTop", body: AccountIdRequest(accountId: accountId))
    }

    func setAccountAvatar(accountId: Int, avatarType: AccountAvatarType, avatar: String = "") async throws -> AccountAvatarResponse {
        try await put("/account/setAvatar", body: AccountAvatarRequest(accountId: accountId, avatarType: avatarType, avatar: avatar))
    }

    func deleteAccount(accountId: Int) async throws {
        let _: EmptyResponse = try await delete("/account/delete", query: [URLQueryItem(name: "accountId", value: String(accountId))])
    }

    func inbox(accountId: Int = 0, allReceive: Bool = true, emailId: Int = 0, size: Int = 30, type: Int = 0) async throws -> MailListResponse {
        try await get(
            "/email/list",
            query: [
                URLQueryItem(name: "accountId", value: String(accountId)),
                URLQueryItem(name: "allReceive", value: allReceive ? "1" : "0"),
                URLQueryItem(name: "emailId", value: String(emailId)),
                URLQueryItem(name: "timeSort", value: "0"),
                URLQueryItem(name: "size", value: String(size)),
                URLQueryItem(name: "type", value: String(type))
            ]
        )
    }

    func starred(emailId: Int = 0, size: Int = 30) async throws -> MailListResponse {
        try await get(
            "/star/list",
            query: [
                URLQueryItem(name: "emailId", value: String(emailId)),
                URLQueryItem(name: "size", value: String(size))
            ]
        )
    }

    func sendEmail(_ request: ComposeEmailRequest) async throws -> ChemVaultEmail {
        try await post("/email/send", body: request)
    }

    func markRead(emailIds: [Int]) async throws {
        let _: EmptyResponse = try await put("/email/read", body: ["emailIds": emailIds])
    }

    func deleteEmails(_ emailIds: [Int]) async throws {
        let joined = emailIds.map(String.init).joined(separator: ",")
        let _: EmptyResponse = try await delete("/email/delete", query: [URLQueryItem(name: "emailIds", value: joined)])
    }

    func addStar(emailId: Int) async throws {
        let _: EmptyResponse = try await post("/star/add", body: ["emailId": emailId])
    }

    func cancelStar(emailId: Int) async throws {
        let _: EmptyResponse = try await delete("/star/cancel", query: [URLQueryItem(name: "emailId", value: String(emailId))])
    }

    func makeRequest<Body: Encodable>(
        _ path: String,
        method: HTTPMethod,
        query: [URLQueryItem] = [],
        body: Body?
    ) throws -> URLRequest {
        guard let baseURL = preferences.baseURL else {
            throw APIError.invalidBaseURL(preferences.baseURLString)
        }

        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var components = URLComponents(url: baseURL.appendingPathComponent(normalizedPath), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidBaseURL(preferences.baseURLString)
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw APIError.invalidBaseURL(preferences.baseURLString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(preferences.language, forHTTPHeaderField: "accept-language")
        if let authToken, !authToken.isEmpty {
            request.setValue(authToken, forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }
        return request
    }

    static func decodeEnvelope<Value: Decodable>(_ type: Value.Type, from data: Data, decoder: JSONDecoder = .chemVault) throws -> Value {
        let envelope = try decoder.decode(APIEnvelope<Value>.self, from: data)
        guard envelope.code == 200 else {
            throw APIError.server(code: envelope.code, message: envelope.message)
        }
        if let data = envelope.data {
            return data
        }
        if Value.self == EmptyResponse.self {
            return EmptyResponse() as! Value
        }
        throw APIError.invalidResponse
    }

    private func request<Body: Encodable, Value: Decodable>(
        _ path: String,
        method: HTTPMethod,
        query: [URLQueryItem] = [],
        body: Body?
    ) async throws -> Value {
        let request = try makeRequest(path, method: method, query: query, body: body)
        do {
            let (data, response) = try await session.data(for: request)
            guard response is HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            return try Self.decodeEnvelope(Value.self, from: data, decoder: decoder)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }
}

private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init<Value: Encodable>(_ value: Value) {
        self.encodeClosure = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}

extension JSONDecoder {
    static var chemVault: JSONDecoder {
        let decoder = JSONDecoder()
        return decoder
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
