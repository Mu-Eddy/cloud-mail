import Foundation
import SwiftUI

struct AdminRegistrationKeysView: View {
    var body: some View {
        AdminEndpointListView(title: "Registration Keys", endpoint: "/regKey/list", query: [])
    }
}

