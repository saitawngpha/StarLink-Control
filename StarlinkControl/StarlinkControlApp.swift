import SwiftUI

@main
struct StarlinkControlApp: App {
    @StateObject private var dashboardViewModel = DashboardViewModel(
        service: GeneratedStarlinkService()
    )

    var body: some Scene {
        WindowGroup {
            DashboardView(viewModel: dashboardViewModel)
        }
    }
}
