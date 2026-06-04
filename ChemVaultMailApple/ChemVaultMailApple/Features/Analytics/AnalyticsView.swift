import Charts
import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @State private var data: AnalyticsData?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let daySendTotal = data?.daySendTotal {
                    LabeledContent("Sent today", value: String(daySendTotal))
                        .font(.headline)
                }

                if let points = data?.emailDayCount?.receiveDayCount, !points.isEmpty {
                    chart(title: "Received Mail", points: points, color: .blue)
                }

                if let points = data?.emailDayCount?.sendDayCount, !points.isEmpty {
                    chart(title: "Sent Mail", points: points, color: .green)
                }

                if let points = data?.userDayCount, !points.isEmpty {
                    chart(title: "New Users", points: points, color: .orange)
                }

                if let ratio = data?.receiveRatio?.nameRatio, !ratio.isEmpty {
                    Chart(ratio) { item in
                        BarMark(
                            x: .value("Sender", item.name),
                            y: .value("Total", item.total)
                        )
                    }
                    .frame(height: 240)
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisValueLabel {
                                if let text = value.as(String.self) {
                                    Text(text).lineLimit(1)
                                }
                            }
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .navigationTitle("Analytics")
        .toolbar {
            Button {
                Task { await load() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .task { await load() }
    }

    private func chart(title: String, points: [AnalyticsPoint], color: Color) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Total", point.total)
                )
                .foregroundStyle(color)
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Total", point.total)
                )
                .foregroundStyle(color)
            }
            .frame(height: 220)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            data = try await appEnvironment.apiClient.get(
                "/analysis/echarts",
                query: [URLQueryItem(name: "timeZone", value: TimeZone.current.identifier)]
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

