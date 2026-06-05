import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authSession: AuthSession
    @EnvironmentObject private var preferences: AppPreferences
    @State private var email = ""
    @State private var password = ""
    @State private var showingRegister = false
    @State private var showingEndpointSettings = false
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .focused($focusedField, equals: .email)

                    SecureField("Password", text: $password)
                        .focused($focusedField, equals: .password)
                        .onSubmit { submit() }
                }

                if let lastError = authSession.lastError {
                    Section {
                        Text(lastError)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        if authSession.state == .checking {
                            ChemVaultLoadingButtonLabel(title: "Signing In")
                        } else {
                            Label("Sign In", systemImage: "arrow.right.circle.fill")
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || authSession.state == .checking)

                    Button("Create Account") {
                        showingRegister = true
                    }
                }

                Section("Server") {
                    HStack {
                        Text("API")
                        Spacer()
                        Text(preferences.baseURLString)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Button("Change API URL") {
                        showingEndpointSettings = true
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("ChemVault Mail")
            .sheet(isPresented: $showingRegister) {
                RegisterView()
            }
            .sheet(isPresented: $showingEndpointSettings) {
                NavigationStack {
                    APIEndpointSettingsView()
                }
            }
        }
    }

    private func submit() {
        focusedField = nil
        Task {
            await authSession.login(email: email, password: password)
        }
    }

    private enum Field {
        case email
        case password
    }
}

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authSession: AuthSession
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var isSubmitting = false
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                    SecureField("Password", text: $password)
                    TextField("Registration key", text: $code)
                }

                if let lastError = authSession.lastError {
                    Section {
                        Text(lastError)
                            .foregroundStyle(.red)
                    }
                }

                if let successMessage {
                    Section {
                        Text(successMessage)
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        if isSubmitting {
                            ChemVaultLoadingButtonLabel(title: "Registering")
                        } else {
                            Label("Register", systemImage: "person.badge.plus")
                        }
                    }
                    .disabled(email.isEmpty || password.count < 6 || isSubmitting)
                }
            }
            .navigationTitle("Create Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func submit() {
        isSubmitting = true
        Task {
            let ok = await authSession.register(email: email, password: password, code: code)
            isSubmitting = false
            if ok {
                successMessage = "Registration succeeded. Sign in with the new account."
            }
        }
    }
}

struct APIEndpointSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        Form {
            Section("API Server") {
                TextField("Base URL", text: $preferences.baseURLString)
                Button("Use Production") {
                    preferences.resetBaseURL()
                }
            }

            Section("Language") {
                Picker("Language", selection: $preferences.language) {
                    Text("English").tag("en")
                    Text("Chinese").tag("zh")
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Connection")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}
