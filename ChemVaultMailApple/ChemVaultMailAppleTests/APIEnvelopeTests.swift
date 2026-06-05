import Foundation
import XCTest
@testable import ChemVaultMailApple

@MainActor
final class APIEnvelopeTests: XCTestCase {
    func testDecodesSuccessfulLoginEnvelope() throws {
        let json = Data(#"{"code":200,"message":"success","data":{"token":"abc123"}}"#.utf8)

        let response = try APIClient.decodeEnvelope(LoginResponse.self, from: json)

        XCTAssertEqual(response, LoginResponse(token: "abc123"))
    }

    func testThrowsServerErrorForNonSuccessEnvelope() throws {
        let json = Data(#"{"code":403,"message":"denied","data":null}"#.utf8)

        XCTAssertThrowsError(try APIClient.decodeEnvelope(EmptyResponse.self, from: json)) { error in
            XCTAssertEqual(error as? APIError, APIError.server(code: 403, message: "denied"))
        }
    }

    func testBuildsAuthorizedLocalizedRequest() throws {
        let defaults = UserDefaults(suiteName: "APIEnvelopeTests-\(UUID().uuidString)")!
        defaults.set("https://example.com/api", forKey: "chemvault.baseURLString")
        defaults.set("zh", forKey: "chemvault.language")
        let preferences = AppPreferences(defaults: defaults)
        let client = APIClient(preferences: preferences)
        client.authToken = "token-value"

        let request = try client.makeRequest(
            "/email/list",
            method: .get,
            query: [URLQueryItem(name: "size", value: "30")],
            body: Optional<EmptyResponse>.none
        )

        XCTAssertEqual(request.url?.absoluteString, "https://example.com/api/email/list?size=30")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "token-value")
        XCTAssertEqual(request.value(forHTTPHeaderField: "accept-language"), "zh")
    }

    func testMigratesLegacyProductionBaseURLToAPIPrefix() {
        let defaults = UserDefaults(suiteName: "APIEnvelopeTests-\(UUID().uuidString)")!
        defaults.set("https://mail.chemvault.science", forKey: "chemvault.baseURLString")

        let preferences = AppPreferences(defaults: defaults)

        XCTAssertEqual(preferences.baseURLString, "https://mail.chemvault.science/api")
        XCTAssertEqual(defaults.string(forKey: "chemvault.baseURLString"), "https://mail.chemvault.science/api")
    }

    func testBuildsAccountActionRequests() async throws {
        AccountRequestURLProtocol.reset()
        let client = makeStubbedClient()

        try await client.setAccountName(accountId: 42, name: "Research Inbox")
        try await client.setAccountAllReceive(accountId: 42)
        try await client.setAccountAsTop(accountId: 42)
        try await client.deleteAccount(accountId: 42)
        let avatar = try await client.setAccountAvatar(accountId: 42, avatarType: .custom, avatar: "https://img.example/avatar.png")

        let requests = AccountRequestURLProtocol.requests
        XCTAssertEqual(requests.map(\.method), ["PUT", "PUT", "PUT", "DELETE", "PUT"])
        XCTAssertEqual(requests.map(\.path), ["/api/account/setName", "/api/account/setAllReceive", "/api/account/setAsTop", "/api/account/delete", "/api/account/setAvatar"])
        XCTAssertEqual(requests[3].query, "accountId=42")
        XCTAssertEqual(requests[0].jsonBody, #"{"accountId":42,"name":"Research Inbox"}"#)
        XCTAssertEqual(requests[1].jsonBody, #"{"accountId":42}"#)
        XCTAssertEqual(requests[2].jsonBody, #"{"accountId":42}"#)
        XCTAssertEqual(requests[4].jsonValue("accountId") as? Int, 42)
        XCTAssertEqual(requests[4].jsonValue("avatarType") as? String, "custom")
        XCTAssertEqual(requests[4].jsonValue("avatar") as? String, "https://img.example/avatar.png")
        XCTAssertEqual(avatar, AccountAvatarResponse(avatarType: .custom, avatar: "https://img.example/avatar.png"))
    }

    func testBuildsAdminUserActionRequests() async throws {
        AccountRequestURLProtocol.reset()
        let client = makeStubbedClient()

        try await client.setAdminUserStatus(userId: 7, status: 1)
        try await client.setAdminUserType(userId: 7, type: 3)
        try await client.setAdminUserPassword(userId: 7, password: "new-secret")
        try await client.resetAdminUserSendCount(userId: 7)

        let requests = AccountRequestURLProtocol.requests
        XCTAssertEqual(requests.map(\.method), ["PUT", "PUT", "PUT", "PUT"])
        XCTAssertEqual(requests.map(\.path), ["/api/user/setStatus", "/api/user/setType", "/api/user/setPwd", "/api/user/resetSendCount"])
        XCTAssertEqual(requests[0].jsonBody, #"{"status":1,"userId":7}"#)
        XCTAssertEqual(requests[1].jsonBody, #"{"type":3,"userId":7}"#)
        XCTAssertEqual(requests[2].jsonBody, #"{"password":"new-secret","userId":7}"#)
        XCTAssertEqual(requests[3].jsonBody, #"{"userId":7}"#)
    }

    func testBuildsAdminUserLifecycleRequests() async throws {
        AccountRequestURLProtocol.reset()
        let client = makeStubbedClient()

        try await client.addAdminUser(email: "ada@chemvault.science", password: "secret-1", type: 4)
        try await client.deleteAdminUsers([7, 8])
        try await client.restoreAdminUser(userId: 7, restoreRelatedData: false)
        try await client.restoreAdminUser(userId: 8, restoreRelatedData: true)

        let requests = AccountRequestURLProtocol.requests
        XCTAssertEqual(requests.map(\.method), ["POST", "DELETE", "PUT", "PUT"])
        XCTAssertEqual(requests.map(\.path), ["/api/user/add", "/api/user/delete", "/api/user/restore", "/api/user/restore"])
        XCTAssertEqual(requests[0].jsonBody, #"{"email":"ada@chemvault.science","password":"secret-1","type":4}"#)
        XCTAssertEqual(requests[1].query, "userIds=7,8")
        XCTAssertEqual(requests[2].jsonBody, #"{"type":0,"userId":7}"#)
        XCTAssertEqual(requests[3].jsonBody, #"{"type":1,"userId":8}"#)
    }

    private func makeStubbedClient() -> APIClient {
        let defaults = UserDefaults(suiteName: "APIEnvelopeTests-\(UUID().uuidString)")!
        defaults.set("https://example.com/api", forKey: "chemvault.baseURLString")
        let preferences = AppPreferences(defaults: defaults)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AccountRequestURLProtocol.self]
        return APIClient(preferences: preferences, session: URLSession(configuration: configuration))
    }
}

private struct CapturedAccountRequest {
    var method: String?
    var path: String
    var query: String?
    var jsonBody: String?
    var jsonObject: [String: Any]?

    func jsonValue(_ key: String) -> Any? {
        jsonObject?[key]
    }
}

private final class AccountRequestURLProtocol: URLProtocol {
    nonisolated(unsafe) private(set) static var requests: [CapturedAccountRequest] = []

    static func reset() {
        requests = []
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let jsonData = request.jsonBodyData()
        Self.requests.append(
            CapturedAccountRequest(
                method: request.httpMethod,
                path: request.url?.path ?? "",
                query: request.url?.query,
                jsonBody: jsonData?.normalizedJSONString(),
                jsonObject: jsonData?.jsonObject()
            )
        )
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let body: Data
        if request.url?.path == "/api/account/setAvatar" {
            body = Data(#"{"code":200,"message":"success","data":{"avatarType":"custom","avatar":"https://img.example/avatar.png"}}"#.utf8)
        } else {
            body = Data(#"{"code":200,"message":"success","data":null}"#.utf8)
        }
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension URLRequest {
    func jsonBodyData() -> Data? {
        httpBody ?? httpBodyStream?.readAllData()
    }
}

private extension Data {
    func normalizedJSONString() -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: self),
              let normalized = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
            return nil
        }
        return String(decoding: normalized, as: UTF8.self)
    }

    func jsonObject() -> [String: Any]? {
        guard let object = try? JSONSerialization.jsonObject(with: self),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }
}

private extension InputStream {
    func readAllData() -> Data {
        open()
        defer { close() }

        let bufferSize = 1_024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var data = Data()
        while hasBytesAvailable {
            let bytesRead = read(buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                data.append(buffer, count: bytesRead)
            } else {
                break
            }
        }
        return data
    }
}
