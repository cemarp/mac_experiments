import Foundation

class AdminShell {
    static let shared = AdminShell()

    private init() {}

    /// Executes a shell command using AppleScript via the `osascript` CLI to request administrator privileges.
    /// This bypasses some internal NSAppleScript threading/sandbox bugs on newer macOS versions.
    /// - Parameter command: The command to run.
    /// - Returns: A tuple containing the standard output as a string and an optional error message.
    func executeWithPrivileges(command: String) -> (output: String?, error: String?) {
        // Escape double quotes and backslashes for AppleScript
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let appleScriptSource = "do shell script \"\(escapedCommand)\" with administrator privileges"

        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e", appleScriptSource]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let errorStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

            if process.terminationStatus != 0 {
                return (output, errorStr?.isEmpty == false ? errorStr : "Process exited with status \(process.terminationStatus)")
            }

            return (output, nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }

    func testPermissions() {
        let result = executeWithPrivileges(command: "whoami")
        print("Test Permissions Output: \(result.output ?? "nil"), Error: \(result.error ?? "nil")")
    }
}
