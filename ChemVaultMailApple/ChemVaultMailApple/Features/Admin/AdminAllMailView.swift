import Foundation
import SwiftUI

struct AdminAllMailView: View {
    var body: some View {
        AdminEndpointListView(
            title: "All Mail",
            endpoint: "/allEmail/list",
            query: [
                URLQueryItem(name: "num", value: "1"),
                URLQueryItem(name: "size", value: "30"),
                URLQueryItem(name: "timeSort", value: "0")
            ]
        )
    }
}

