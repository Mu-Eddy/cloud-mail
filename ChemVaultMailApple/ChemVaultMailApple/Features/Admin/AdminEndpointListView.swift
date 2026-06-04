import SwiftUI

struct AdminEndpointListView: View {
    let title: String
    let endpoint: String
    let query: [URLQueryItem]

    @EnvironmentObject private var appEnvironment: AppEnvironment
    @State private var payload: JSONValue?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let payload {
                JSONValueSection(value: payload)
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
            } else if payload == nil && errorMessage == nil {
                ContentUnavailableView(title, systemImage: "tablecells", description: Text("No data loaded."))
            }
        }
        .navigationTitle(title)
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
            payload = try await appEnvironment.apiClient.rawGet(endpoint, query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct JSONValueSection: View {
    let value: JSONValue

    var body: some View {
        switch value {
        case .array(let values):
            Section("Items") {
                ForEach(Array(values.enumerated()), id: \.offset) { index, item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Item \(index + 1)")
                            .font(.headline)
                        Text(item.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                }
            }
        case .object(let object):
            ForEach(object.keys.sorted(), id: \.self) { key in
                Section(key) {
                    Text(object[key]?.description ?? "")
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }
        default:
            Section("Data") {
                Text(value.description)
                    .font(.caption)
                    .textSelection(.enabled)
            }
        }
    }
}

