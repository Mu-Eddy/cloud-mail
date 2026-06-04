import Foundation
import SwiftUI

struct AdminUsersView: View {
    var body: some View {
        AdminEndpointListView(
            title: "Users",
            endpoint: "/user/list",
            query: [
                URLQueryItem(name: "num", value: "1"),
                URLQueryItem(name: "size", value: "30"),
                URLQueryItem(name: "status", value: "-1"),
                URLQueryItem(name: "timeSort", value: "0"),
                URLQueryItem(name: "isDel", value: "0")
            ]
        )
    }
}

