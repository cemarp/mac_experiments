import Foundation

class AdminShell {
    static let shared = AdminShell()

    private init() {}

    /// Executes a shell command using AppleScript to request administrator privileges.
    /// - Parameter command: The command to run.
    /// - Returns: A tuple containing the standard output as a string and an optional error message.
    func executeWithPrivileges(command: String) -> (output: String?, error: String?) {
        // Escape double quotes and backslashes for AppleScript
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        // We do not append 2>/dev/null to the AppleScript command string itself,
        // because AppleScript evaluates it directly. We handled it in the Swift side.
        let appleScriptSource = "do shell script \"\(escapedCommand)\" with administrator privileges"

        var errorDict: NSDictionary?
        guard let appleScript = NSAppleScript(source: appleScriptSource) else {
            return (nil, "Failed to initialize NSAppleScript")
        }

        let result = appleScript.executeAndReturnError(&errorDict)

        if let errorDict = errorDict {
            let errorMsg = errorDict[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            return (nil, errorMsg)
        }

        return (result.stringValue, nil)
    }

    func testPermissions() {
        let result = executeWithPrivileges(command: "whoami")
        print("Test Permissions Output: \(result.output ?? "nil"), Error: \(result.error ?? "nil")")
    }
}
