import Foundation
import SwiftUI

struct AdminRolesView: View {
    var body: some View {
        AdminEndpointListView(title: "Roles", endpoint: "/role/list", query: [])
    }
}

