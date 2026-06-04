import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidBaseURL(String)
    case invalidResponse
    case server(code: Int, message: String)
    case transport(String)
    case missingToken

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let value):
            return "Invalid API URL: \(value)"
        case .invalidResponse:
            return "The server returned an invalid response."
        case .server(_, let message):
            return message
        case .transport(let message):
            return message
        case .missingToken:
            return "No saved session token is available."
        }
    }

    var statusCode: Int? {
        if case .server(let code, _) = self {
            return code
        }
        return nil
    }
}

