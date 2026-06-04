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
}

