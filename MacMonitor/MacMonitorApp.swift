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
                    let buildTime = Bundle.main.infoDictionary?["BuildTime"] as? String ?? "Unknown"
                    let gitHash = Bundle.main.infoDictionary?["GitCommitHash"] as? String ?? "Unknown"

                    let alert = NSAlert()
                    alert.messageText = "MacMonitor"
                    alert.informativeText = "Version 1.0\nBuild Time: \(buildTime)\nGit Hash: \(gitHash)"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
}
