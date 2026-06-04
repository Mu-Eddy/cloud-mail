import SwiftUI

enum AppRoute: String, CaseIterable, Identifiable, Hashable {
    case mail
    case starred
    case accounts
    case settings
    case adminUsers
    case adminRoles
    case adminRegistrationKeys
    case adminAllMail
    case adminSystemSettings
    case analytics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mail: return "Inbox"
        case .starred: return "Starred"
        case .accounts: return "Accounts"
        case .settings: return "Settings"
        case .adminUsers: return "Users"
        case .adminRoles: return "Roles"
        case .adminRegistrationKeys: return "Registration Keys"
        case .adminAllMail: return "All Mail"
        case .adminSystemSettings: return "System Settings"
        case .analytics: return "Analytics"
        }
    }

    var systemImage: String {
        switch self {
        case .mail: return "tray.full"
        case .starred: return "star"
        case .accounts: return "person.2"
        case .settings: return "gearshape"
        case .adminUsers: return "person.crop.circle.badge.gearshape"
        case .adminRoles: return "key.horizontal"
        case .adminRegistrationKeys: return "ticket"
        case .adminAllMail: return "archivebox"
        case .adminSystemSettings: return "slider.horizontal.3"
        case .analytics: return "chart.xyaxis.line"
        }
    }

    var permissionKey: String? {
        switch self {
        case .mail, .starred, .accounts, .settings:
            return nil
        case .adminUsers:
            return "user:query"
        case .adminRoles:
            return "role:query"
        case .adminRegistrationKeys:
            return "reg-key:query"
        case .adminAllMail:
            return "all-email:query"
        case .adminSystemSettings:
            return "setting:query"
        case .analytics:
            return "analysis:query"
        }
    }

    var groupTitle: String {
        switch self {
        case .mail, .starred:
            return "Mail"
        case .accounts, .settings:
            return "Personal"
        case .adminUsers, .adminRoles, .adminRegistrationKeys, .adminAllMail, .adminSystemSettings:
            return "Admin"
        case .analytics:
            return "Insights"
        }
    }

    func isAvailable(for user: ChemVaultUser?) -> Bool {
        guard let permissionKey else { return true }
        return user?.hasPermission(permissionKey) ?? false
    }
}

