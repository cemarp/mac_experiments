import SwiftUI

@main
struct MacMonitorApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            DashboardView(viewModel: viewModel)
        }
        .windowResizability(.contentSize)
    }
}
