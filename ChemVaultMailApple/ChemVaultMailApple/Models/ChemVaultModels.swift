import Foundation

struct APIEnvelope<Value: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: Value?
}

struct EmptyResponse: Codable, Equatable {
    init() {}
}

struct LoginResponse: Codable, Equatable {
    let token: String
}

struct RegisterResponse: Codable, Equatable {
    var regVerifyOpen: Bool?
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let code: String?
    let token: String?
}

struct ChemVaultAccount: Codable, Identifiable, Hashable {
    var accountId: Int
    var email: String
    var name: String?
    var avatarType: String?
    var avatar: String?
    var status: Int?
    var latestEmailTime: String?
    var createTime: String?
    var userId: Int?
    var allReceive: Int?
    var sort: Int?
    var isDel: Int?
    var addVerifyOpen: Bool?

    var id: Int { accountId }
    var displayName: String { (name?.isEmpty == false ? name : nil) ?? email }
}

struct ChemVaultUser: Codable, Identifiable, Hashable {
    var userId: Int
    var email: String
    var name: String?
    var type: Int?
    var sendCount: Int?
    var account: ChemVaultAccount?
    var role: ChemVaultRole?
    var permKeys: [String]?
    var status: Int?
    var createTime: String?
    var activeTime: String?
    var receiveEmailCount: Int?
    var sendEmailCount: Int?
    var accountCount: Int?

    var id: Int { userId }

    func hasPermission(_ key: String) -> Bool {
        guard let permKeys else { return false }
        return permKeys.contains("*") || permKeys.contains(key)
    }
}

struct PagedListResponse<Value: Decodable>: Decodable {
    var list: [Value]
    var total: Int?

    private enum CodingKeys: String, CodingKey {
        case list
        case total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.list = try container.decodeIfPresent([Value].self, forKey: .list) ?? []
        self.total = try container.decodeFlexibleIntIfPresent(forKey: .total)
    }
}

struct AdminUserRow: Codable, Identifiable, Hashable {
    var userId: Int
    var email: String
    var type: Int?
    var status: Int?
    var createTime: String?
    var activeTime: String?
    var username: String?
    var name: String?
    var avatar: String?
    var receiveEmailCount: Int?
    var sendEmailCount: Int?
    var accountCount: Int?
    var delReceiveEmailCount: Int?
    var delSendEmailCount: Int?
    var delAccountCount: Int?
    var sendAction: JSONValue?

    var id: Int { userId }

    var displayName: String {
        if let name, !name.isEmpty { return name }
        if let username, !username.isEmpty { return username }
        return email
    }

    var statusLabel: String {
        switch status {
        case 0: return "Active"
        case 1: return "Disabled"
        case 2: return "Pending"
        default: return "Unknown"
        }
    }
}

struct ChemVaultRole: Codable, Identifiable, Hashable {
    var roleId: Int
    var name: String
    var key: String?
    var description: String?
    var banEmail: JSONValue?
    var banEmailType: Int?
    var availDomain: JSONValue?
    var sort: Int?
    var isDefault: Int?
    var createTime: String?
    var userId: Int?
    var sendCount: Int?
    var sendType: String?
    var accountCount: Int?
    var permIds: [Int]?

    var id: Int { roleId }
}

struct ChemVaultEmail: Codable, Identifiable, Hashable {
    var emailId: Int
    var sendEmail: String?
    var name: String?
    var accountId: Int?
    var userId: Int?
    var subject: String?
    var code: String?
    var text: String?
    var content: String?
    var cc: JSONValue?
    var bcc: JSONValue?
    var recipient: String?
    var toEmail: String?
    var toName: String?
    var inReplyTo: String?
    var relation: String?
    var messageId: String?
    var type: Int?
    var status: Int?
    var resendEmailId: String?
    var message: String?
    var unread: Int?
    var createTime: String?
    var isDel: Int?
    var starId: Int?
    var isStar: Int?
    var userEmail: String?
    var attList: [ChemVaultAttachment]?

    var id: Int { emailId }
    var title: String { subject?.isEmpty == false ? subject! : "(No subject)" }
    var senderLine: String { name?.isEmpty == false ? name! : (sendEmail ?? toEmail ?? "Unknown sender") }
    var previewText: String { text?.isEmpty == false ? text! : (message ?? "") }
    var isUnread: Bool { unread == 0 || unread == 1 }
    var starred: Bool { (isStar ?? 0) != 0 || starId != nil }
}

struct ChemVaultAttachment: Codable, Identifiable, Hashable {
    var attId: Int
    var userId: Int?
    var emailId: Int?
    var accountId: Int?
    var key: String
    var filename: String?
    var mimeType: String?
    var size: Int?
    var status: JSONValue?
    var type: Int?
    var disposition: String?
    var related: String?
    var contentId: String?
    var encoding: String?
    var createTime: String?

    var id: Int { attId }
}

struct MailListResponse: Decodable, Equatable {
    var list: [ChemVaultEmail]
    var total: Int?
    var latestEmail: ChemVaultEmail?

    init(list: [ChemVaultEmail], total: Int? = nil, latestEmail: ChemVaultEmail? = nil) {
        self.list = list
        self.total = total
        self.latestEmail = latestEmail
    }

    private enum CodingKeys: String, CodingKey {
        case list
        case total
        case latestEmail
    }

    init(from decoder: Decoder) throws {
        if let array = try? [ChemVaultEmail](from: decoder) {
            self.list = array
            self.total = nil
            self.latestEmail = array.first
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.list = try container.decodeIfPresent([ChemVaultEmail].self, forKey: .list) ?? []
        self.total = try container.decodeFlexibleIntIfPresent(forKey: .total)
        self.latestEmail = try container.decodeIfPresent(ChemVaultEmail.self, forKey: .latestEmail)
    }
}

struct ComposeEmailRequest: Encodable {
    var accountId: Int
    var name: String?
    var sendType: String
    var emailId: Int?
    var receiveEmail: [String]
    var text: String
    var content: String
    var subject: String
    var attachments: [ComposeAttachment]
}

struct ComposeAttachment: Codable, Hashable {
    var filename: String
    var content: String
    var mimeType: String?
    var contentId: String?
}

struct AccountAddRequest: Encodable {
    var email: String
    var token: String?
}

struct AccountIdRequest: Encodable {
    var accountId: Int
}

struct AccountNameRequest: Encodable {
    var accountId: Int
    var name: String
}

enum AccountAvatarType: String, Codable, CaseIterable, Identifiable {
    case initial
    case logo
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .initial: return "Initial"
        case .logo: return "Logo"
        case .custom: return "Custom"
        }
    }
}

struct AccountAvatarRequest: Encodable {
    var accountId: Int
    var avatarType: AccountAvatarType
    var avatar: String
}

struct AccountAvatarResponse: Codable, Equatable {
    var avatarType: AccountAvatarType
    var avatar: String
}

struct PasswordResetRequest: Encodable {
    var password: String
}

struct RegistrationKey: Codable, Identifiable, Hashable {
    var regKeyId: Int
    var code: String
    var count: Int?
    var roleId: Int?
    var roleName: String?
    var userId: Int?
    var expireTime: String?
    var createTime: String?

    var id: Int { regKeyId }
}

struct ChemVaultSetting: Codable, Hashable {
    var register: Int?
    var receive: Int?
    var title: String?
    var manyEmail: Int?
    var addEmail: Int?
    var autoRefresh: Int?
    var send: Int?
    var r2Domain: String?
    var siteKey: String?
    var regKey: Int?
    var background: String?
    var domainList: [String]?
    var noticeTitle: String?
    var noticeContent: String?
    var minEmailPrefix: Int?
    var emailPrefixFilter: JSONValue?
    var blackSubject: String?
    var blackContent: String?
    var blackFrom: String?
}

struct AnalyticsData: Codable, Hashable {
    var numberCount: JSONValue?
    var userDayCount: [AnalyticsPoint]?
    var receiveRatio: ReceiveRatio?
    var emailDayCount: EmailDayCount?
    var daySendTotal: Int?
}

struct ReceiveRatio: Codable, Hashable {
    var nameRatio: [AnalyticsNameCount]?
}

struct EmailDayCount: Codable, Hashable {
    var receiveDayCount: [AnalyticsPoint]?
    var sendDayCount: [AnalyticsPoint]?
}

struct AnalyticsPoint: Codable, Identifiable, Hashable {
    var date: String
    var total: Int

    var id: String { date }
}

struct AnalyticsNameCount: Codable, Identifiable, Hashable {
    var name: String
    var total: Int

    var id: String { name }
}

enum JSONValue: Codable, Hashable, CustomStringConvertible {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .number(Double(value))
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var description: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value.rounded() == value ? String(Int(value)) : String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .object(let value):
            return value.map { "\($0.key): \($0.value.description)" }.sorted().joined(separator: ", ")
        case .array(let value):
            return value.map(\.description).joined(separator: ", ")
        case .null:
            return ""
        }
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }
}

extension KeyedDecodingContainer {
    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }
        return nil
    }
}
