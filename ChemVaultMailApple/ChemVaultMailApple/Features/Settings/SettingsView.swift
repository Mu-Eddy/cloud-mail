import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authSession: AuthSession
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @State private var newPassword = ""
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section("Profile") {
                LabeledContent("Email", value: authSession.currentUser?.email ?? "Not loaded")
                LabeledContent("Name", value: authSession.currentUser?.name ?? "")
                LabeledContent("Role", value: authSession.currentUser?.role?.name ?? "")
                Button("Refresh Profile") {
                    Task { await authSession.refreshUser() }
                }
            }

            Section("Connection") {
                TextField("API Base URL", text: $preferences.baseURLString)
                Picker("Language", selection: $preferences.language) {
                    Text("English").tag("en")
                    Text("Chinese").tag("zh")
                }
                Button("Use Production API") {
                    preferences.resetBaseURL()
                }
            }

            Section("Password") {
                SecureField("New password", text: $newPassword)
                Button("Reset Password") {
                    resetPassword()
                }
                .disabled(newPassword.count < 6)
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .foregroundStyle(.green)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(role: .destructive) {
                    authSession.signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Settings")
    }

    private func resetPassword() {
        Task {
            do {
                let _: EmptyResponse = try await appEnvironment.apiClient.put("/my/resetPassword", body: PasswordResetRequest(password: newPassword))
                newPassword = ""
                statusMessage = "Password updated."
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
