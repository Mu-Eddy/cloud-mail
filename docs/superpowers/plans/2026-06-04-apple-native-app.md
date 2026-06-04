# ChemVault Mail Apple Native App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native SwiftUI Universal App for ChemVault Mail that connects to the existing Cloudflare Worker backend and covers the web app's mail, settings, admin, and analytics capabilities.

**Architecture:** Create a new `ChemVaultMailApple` Xcode project with shared SwiftUI source for iOS, iPadOS, and macOS. Keep networking, auth, models, and stores platform-neutral, while the root layout adapts between iPhone navigation and iPad/macOS split views. The first implementation pass creates a buildable app with the main architecture, auth, mail, account/settings/admin shells, and tested API/model foundations.

**Tech Stack:** Swift 6.3, SwiftUI, Foundation URLSession, Security Keychain, WebKit for HTML message body rendering, Charts for analytics, XCTest.

---

### Task 1: Scaffold Universal Xcode Project

**Files:**
- Create: `ChemVaultMailApple/ChemVaultMailApple.xcodeproj/project.pbxproj`
- Create: `ChemVaultMailApple/ChemVaultMailApple/App/ChemVaultMailAppleApp.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/App/ContentView.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/Resources/Info.plist`
- Create: `ChemVaultMailApple/ChemVaultMailAppleTests/ChemVaultMailAppleTests.swift`
- Create: `ChemVaultMailApple/scripts/generate_project.rb`
- Create: `ChemVaultMailApple/script/build_and_run.sh`
- Create: `.codex/environments/environment.toml`

- [ ] **Step 1: Create the source folders**

Run:

```bash
mkdir -p ChemVaultMailApple/ChemVaultMailApple/{App,Core,Models,Features,Resources,PreviewSupport}
mkdir -p ChemVaultMailApple/ChemVaultMailAppleTests
mkdir -p ChemVaultMailApple/{scripts,script}
mkdir -p .codex/environments
```

- [ ] **Step 2: Add the minimal SwiftUI app entry point**

Create `ChemVaultMailApple/ChemVaultMailApple/App/ChemVaultMailAppleApp.swift`:

```swift
import SwiftUI

@main
struct ChemVaultMailAppleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [ ] **Step 3: Add the initial content view**

Create `ChemVaultMailApple/ChemVaultMailApple/App/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("ChemVault Mail")
    }
}
```

- [ ] **Step 4: Generate the Xcode project**

Run:

```bash
GEM_PATH=/tmp/codex-xcodeproj-gems ruby ChemVaultMailApple/scripts/generate_project.rb
```

Expected: `ChemVaultMailApple/ChemVaultMailApple.xcodeproj` exists and has one app target plus one test target.

- [ ] **Step 5: Build the scaffold**

Run:

```bash
xcodebuild -project ChemVaultMailApple/ChemVaultMailApple.xcodeproj -scheme ChemVaultMailApple -destination 'generic/platform=macOS' build
```

Expected: `** BUILD SUCCEEDED **`.

### Task 2: Core API, Auth, And Models

**Files:**
- Create: `ChemVaultMailApple/ChemVaultMailApple/Core/APIClient.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/Core/APIError.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/Core/AppEnvironment.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/Core/AuthSession.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/Core/KeychainTokenStore.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/Models/ChemVaultModels.swift`
- Modify: `ChemVaultMailApple/ChemVaultMailApple/App/ChemVaultMailAppleApp.swift`
- Test: `ChemVaultMailApple/ChemVaultMailAppleTests/APIEnvelopeTests.swift`

- [ ] **Step 1: Add Codable models matching Worker payloads**

Add flexible `Codable`, `Identifiable`, and date-safe models for login, user, account, email, attachment, settings, roles, registration keys, all-mail, and analytics payloads.

- [ ] **Step 2: Add envelope decoding**

Implement:

```swift
struct APIEnvelope<Value: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: Value?
}
```

Non-200 codes must throw `APIError.server(code:message:)`.

- [ ] **Step 3: Add URLSession client**

Implement typed `get`, `post`, `put`, and `delete` methods that attach `Authorization` and `accept-language`.

- [ ] **Step 4: Add Keychain token persistence**

Implement a small Security-framework wrapper with `readToken`, `saveToken`, and `deleteToken`.

- [ ] **Step 5: Add tests**

Run:

```bash
xcodebuild -project ChemVaultMailApple/ChemVaultMailApple.xcodeproj -scheme ChemVaultMailApple -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: envelope and request construction tests pass.

### Task 3: Adaptive App Shell

**Files:**
- Create: `ChemVaultMailApple/ChemVaultMailApple/App/AppRoute.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/App/AppShellView.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/App/SidebarView.swift`
- Modify: `ChemVaultMailApple/ChemVaultMailApple/App/ContentView.swift`

- [ ] **Step 1: Add route enum**

Use `AppRoute` cases: `mail`, `starred`, `accounts`, `settings`, `adminUsers`, `adminRoles`, `adminRegistrationKeys`, `adminAllMail`, `adminSystemSettings`, and `analytics`.

- [ ] **Step 2: Add responsive shell**

Use `NavigationSplitView` for regular horizontal size classes and macOS, with compact fallback using `TabView`.

- [ ] **Step 3: Wire foundation feature screens**

Each module must have a native foundation screen with real navigation title and toolbar placement, not a WebView.

### Task 4: Authentication UI

**Files:**
- Create: `ChemVaultMailApple/ChemVaultMailApple/Features/Auth/LoginView.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/Features/Auth/RegisterView.swift`
- Modify: `ChemVaultMailApple/ChemVaultMailApple/App/ContentView.swift`
- Modify: `ChemVaultMailApple/ChemVaultMailApple/Core/AuthSession.swift`

- [ ] **Step 1: Implement login form**

Fields: email and password. Actions: login, register, custom API URL in settings sheet. On success, store token and load user info.

- [ ] **Step 2: Implement registration form**

Fields follow backend `register(form)` request shape with email, password, and registration key.

- [ ] **Step 3: Add loading and error states**

Disable submit while logging in and show backend messages on failure.

### Task 5: Mail Client Foundation

**Files:**
- Create: `ChemVaultMailApple/ChemVaultMailApple/Features/Mail/MailStore.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/Features/Mail/MailListView.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/Features/Mail/MailDetailView.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/Features/Mail/HTMLMessageView.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/Features/Mail/ComposeView.swift`
- Modify: `ChemVaultMailApple/ChemVaultMailApple/App/AppShellView.swift`

- [ ] **Step 1: Implement inbox and starred loaders**

Call `/email/list` and `/star/list`, supporting page size, last email id, account id, and all-receive flags.

- [ ] **Step 2: Implement mail row and detail**

Show sender, subject, preview text, unread status, star state, time, recipients, and message body.

- [ ] **Step 3: Implement compose foundation**

Fields: from account, to, cc, bcc, subject, body. Call `/email/send` with JSON body.

- [ ] **Step 4: Add delete, read, star, and refresh**

Call `/email/delete`, `/email/read`, `/star/add`, `/star/cancel`, and `/email/latest`.

### Task 6: Accounts And Settings

**Files:**
- Create: `ChemVaultMailApple/ChemVaultMailApple/Features/Accounts/AccountsView.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/Features/Settings/SettingsView.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/Features/Settings/SystemSettingsView.swift`

- [ ] **Step 1: Add account list and actions**

Call `/account/list`, `/account/add`, `/account/setName`, `/account/setAvatar`, `/account/delete`, `/account/setAllReceive`, and `/account/setAsTop`.

- [ ] **Step 2: Add personal settings**

Call `/my/loginUserInfo`, `/my/resetPassword`, `/my/delete`, `/logout`, and persist app preferences.

- [ ] **Step 3: Add system settings**

Call `/setting/query`, `/setting/set`, `/setting/websiteConfig`, `/setting/setBackground`, `/setting/deleteBackground`, and `/setting/setBlacklist`.

### Task 7: Admin And Analytics

**Files:**
- Create: `ChemVaultMailApple/ChemVaultMailApple/Features/Admin/AdminUsersView.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/Features/Admin/AdminRolesView.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/Features/Admin/AdminRegistrationKeysView.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/Features/Admin/AdminAllMailView.swift`
- Create: `ChemVaultMailApple/ChemVaultMailApple/Features/Analytics/AnalyticsView.swift`

- [ ] **Step 1: Add user management screens**

Call `/user/list`, `/user/add`, `/user/setPwd`, `/user/setStatus`, `/user/setType`, `/user/delete`, `/user/resetSendCount`, `/user/restore`, `/user/allAccount`, `/user/setAccountAvatar`, `/user/setUserAvatar`, and `/user/deleteAccount`.

- [ ] **Step 2: Add role management screens**

Call `/role/tree`, `/role/list`, `/role/add`, `/role/set`, `/role/setDefault`, `/role/delete`, and `/role/selectUse`.

- [ ] **Step 3: Add registration key and all-mail screens**

Call `/regKey/list`, `/regKey/add`, `/regKey/delete`, `/regKey/clearNotUse`, `/regKey/history`, `/allEmail/list`, `/allEmail/delete`, `/allEmail/batchDelete`, and `/allEmail/latest`.

- [ ] **Step 4: Add analytics screen**

Call `/analysis/echarts` and render charts with Swift Charts.

### Task 8: Verification And Handoff

**Files:**
- Modify as needed based on build and test failures.

- [ ] **Step 1: Run iOS simulator build**

Run:

```bash
xcodebuild -project ChemVaultMailApple/ChemVaultMailApple.xcodeproj -scheme ChemVaultMailApple -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Run macOS build**

Run:

```bash
xcodebuild -project ChemVaultMailApple/ChemVaultMailApple.xcodeproj -scheme ChemVaultMailApple -destination 'generic/platform=macOS' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Run tests**

Run:

```bash
xcodebuild -project ChemVaultMailApple/ChemVaultMailApple.xcodeproj -scheme ChemVaultMailApple -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`.
