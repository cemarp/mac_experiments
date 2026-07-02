import Foundation

class LocalSystemMonitor {
    static let shared = LocalSystemMonitor()

    private var latestMetrics = SystemMetrics(
        totalPower: 0,
        cpuPower: 0,
        gpuPower: 0,
        anePower: 0,
        cpuTemp: 0,
        gpuTemp: 0,
        batteryTemp: 0,
        batteryLevel: 0,
        batteryCycles: 0,
        isCharging: false,
        isDischarging: false
    )

    private let queue = DispatchQueue(label: "com.yourdomain.MacMonitor.MetricsQueue")

    private init() {}

    func getMetrics(completion: @escaping (SystemMetrics?, Error?) -> Void) {
        queue.async {
            let totalPower = Double.random(in: 5...30)
            let cpuPower = Double.random(in: 1...15)
            let gpuPower = Double.random(in: 0...10)
            let anePower = Double.random(in: 0...2)
            let cpuTemp = Double.random(in: 40...80)
            let gpuTemp = Double.random(in: 40...75)
            let batteryTemp = Double.random(in: 25...40)

            let batteryInfo = self.getBatteryInfo()

            self.latestMetrics = SystemMetrics(
                totalPower: totalPower,
                cpuPower: cpuPower,
                gpuPower: gpuPower,
                anePower: anePower,
                cpuTemp: cpuTemp,
                gpuTemp: gpuTemp,
                batteryTemp: batteryTemp,
                batteryLevel: batteryInfo.level,
                batteryCycles: batteryInfo.cycles,
                isCharging: batteryInfo.isCharging,
                isDischarging: !batteryInfo.isCharging
            )

            completion(self.latestMetrics, nil)
        }
    }

    private func getBatteryInfo() -> (level: Double, cycles: Int, isCharging: Bool) {
        return (80.0, 150, false)
    }

    func updateBatteryControlState(_ state: BatteryControlState, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            print("Received new battery control state: Limit: \(state.chargeLimit), Sailing: \(state.sailingModeEnabled), Force Discharge: \(state.forceDischarge)")

            guard let smcUtilURL = Bundle.main.url(forResource: "smc_util", withExtension: nil) else {
                print("[ERROR] Could not find smc_util in app bundle")
                completion(false, nil)
                return
            }
            let smcUtilPath = smcUtilURL.path
            let inhibitValue = state.forceDischarge ? 1 : 0

            // Execute the embedded privileged command line tool.
            // AdminShell safely escapes double quotes and backslashes in the command string, but we must
            // also properly escape the path to the executable to prevent shell injection if the app is placed
            // in a path containing single quotes or other shell metacharacters.
            // The safest way in a single shell command without complex escaping is to cd to the directory
            // or pass arguments properly. AppleScript's 'quoted form of' handles this best, but we are
            // building the string here. We can use a small wrapper function or manually escape.

            let escapedPath = smcUtilPath.replacingOccurrences(of: "'", with: "'\\''")

            let combinedCmd = "'\(escapedPath)' BCLM \(state.chargeLimit) && '\(escapedPath)' CH0I \(inhibitValue)"

            print("[INSTRUMENTATION] Attempting to execute: \(combinedCmd)")
            let writeResult = AdminShell.shared.executeWithPrivileges(command: combinedCmd)
            print("[INSTRUMENTATION] Write combined result: \(writeResult.output ?? "none"), error: \(writeResult.error ?? "none")")

            completion(true, nil)
        }
    }
}
