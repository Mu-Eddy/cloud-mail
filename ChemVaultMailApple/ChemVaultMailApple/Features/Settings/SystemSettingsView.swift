import SwiftUI

struct SystemSettingsView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @State private var settings: ChemVaultSetting?
    @State private var rawSettings: JSONValue?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let settings {
                Section("Website") {
                    LabeledContent("Title", value: settings.title ?? "")
                    LabeledContent("Send", value: settings.send.map(String.init) ?? "")
                    LabeledContent("Receive", value: settings.receive.map(String.init) ?? "")
                    LabeledContent("Register", value: settings.register.map(String.init) ?? "")
                    LabeledContent("R2 Domain", value: settings.r2Domain ?? "")
                }
            }

            if let rawSettings {
                Section("Raw Settings") {
                    Text(rawSettings.description)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .navigationTitle("System Settings")
        .toolbar {
            Button {
                Task { await load() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            settings = try await appEnvironment.apiClient.get("/setting/query")
            rawSettings = try? await appEnvironment.apiClient.rawGet("/setting/query")
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

