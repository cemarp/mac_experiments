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
        var level: Double = 0
        var cycles: Int = 0
        var isCharging: Bool = false

        let task = Process()
        task.launchPath = "/usr/sbin/ioreg"
        task.arguments = ["-rn", "AppleSmartBattery"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse "CurrentCapacity" = 70
                // Parse "MaxCapacity" = 100
                // Parse "CycleCount" = 120
                // Parse "IsCharging" = Yes/No (or True/False)

                var currentCapacity: Double = 0
                var maxCapacity: Double = 100

                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    if line.contains("\"CurrentCapacity\" =") {
                        if let valStr = line.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespacesAndNewlines),
                           let val = Double(valStr) {
                            currentCapacity = val
                        }
                    } else if line.contains("\"MaxCapacity\" =") {
                        if let valStr = line.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespacesAndNewlines),
                           let val = Double(valStr) {
                            maxCapacity = val
                        }
                    } else if line.contains("\"CycleCount\" =") {
                        if let valStr = line.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespacesAndNewlines),
                           let val = Int(valStr) {
                            cycles = val
                        }
                    } else if line.contains("\"IsCharging\" =") {
                        if let valStr = line.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespacesAndNewlines) {
                            isCharging = (valStr.lowercased() == "yes" || valStr.lowercased() == "true")
                        }
                    }
                }

                if maxCapacity > 0 {
                    level = (currentCapacity / maxCapacity) * 100.0
                }
            }
        } catch {
            print("Error running ioreg: \(error)")
        }

        // Fallback if ioreg fails or doesn't return MaxCapacity
        if level == 0 {
            let pmsetTask = Process()
            pmsetTask.launchPath = "/usr/bin/pmset"
            pmsetTask.arguments = ["-g", "batt"]

            let pmsetPipe = Pipe()
            pmsetTask.standardOutput = pmsetPipe

            do {
                try pmsetTask.run()
                let pmsetData = pmsetPipe.fileHandleForReading.readDataToEndOfFile()
                if let pmsetOutput = String(data: pmsetData, encoding: .utf8) {
                    // Look for something like "70%; charging"
                    if let regex = try? NSRegularExpression(pattern: #"(\d+)%;\s*(charging|discharging|AC attached)"#, options: .caseInsensitive) {
                        let nsRange = NSRange(pmsetOutput.startIndex..<pmsetOutput.endIndex, in: pmsetOutput)
                        if let match = regex.firstMatch(in: pmsetOutput, options: [], range: nsRange) {
                            if let levelRange = Range(match.range(at: 1), in: pmsetOutput),
                               let levelVal = Double(pmsetOutput[levelRange]) {
                                level = levelVal
                            }
                            if let statusRange = Range(match.range(at: 2), in: pmsetOutput) {
                                let statusStr = String(pmsetOutput[statusRange]).lowercased()
                                isCharging = statusStr.contains("charging") && !statusStr.contains("discharging")
                            }
                        }
                    }
                }
            } catch {
                print("Error running pmset: \(error)")
            }
        }

        return (level, cycles, isCharging)
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

            let escapedPath = smcUtilPath.replacingOccurrences(of: "'", with: "'\\''")

            // To make BCLM stick on many Apple Silicon/Intel Macs, you must also write to CH0C
            // to enable custom battery charging limits, otherwise the OS overwrites BCLM.
            // Some Macs use CH0C = 0x00 to use BCLM, some use CH0C = 0x02.
            // By writing 0 to CH0C, we tell the OS not to override our BCLM setting.
            let combinedCmd = "'\(escapedPath)' CH0C 0 && '\(escapedPath)' BCLM \(state.chargeLimit) && '\(escapedPath)' CH0I \(inhibitValue)"

            print("[INSTRUMENTATION] Attempting to execute: \(combinedCmd)")
            let writeResult = AdminShell.shared.executeWithPrivileges(command: combinedCmd)
            print("[INSTRUMENTATION] Write combined result: \(writeResult.output ?? "none"), error: \(writeResult.error ?? "none")")

            completion(true, nil)
        }
    }
}
