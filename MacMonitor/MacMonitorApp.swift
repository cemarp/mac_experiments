import SwiftUI

@main
struct MacMonitorApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            DashboardView(viewModel: viewModel)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About MacMonitor") {
                    let alert = NSAlert()
                    alert.messageText = "MacMonitor"
                    alert.informativeText = "Version 1.0\nBuild Time: \(BuildInfo.buildTime)\nGit Hash: \(BuildInfo.gitHash)"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
}
