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
            // Process pipeline for powermetrics
            let command = "powermetrics -n 1 --samplers smc,cpu_power,gpu_power"
            let result = AdminShell.shared.executeWithPrivileges(command: command)

            var totalPower = 0.0
            var cpuPower = 0.0
            var gpuPower = 0.0
            var anePower = 0.0
            var cpuTemp = 0.0
            var gpuTemp = 0.0
            let batteryTemp = Double.random(in: 25...40) // Cannot parse from simulated without specific regex

            if let output = result.output {
                // Regex scaffolding

                // Example: CPU Power: 10.5 W
                if let cpuMatch = output.range(of: #"CPU Power: (\d+\.\d+)"#, options: .regularExpression) {
                    let valStr = output[cpuMatch].split(separator: " ")[2]
                    cpuPower = Double(valStr) ?? 0.0
                }

                // Example: GPU Power: 5.2 W
                if let gpuMatch = output.range(of: #"GPU Power: (\d+\.\d+)"#, options: .regularExpression) {
                    let valStr = output[gpuMatch].split(separator: " ")[2]
                    gpuPower = Double(valStr) ?? 0.0
                }

                // Total Power
                if let combinedMatch = output.range(of: #"Combined Power: (\d+\.\d+)"#, options: .regularExpression) {
                    let valStr = output[combinedMatch].split(separator: " ")[2]
                    totalPower = Double(valStr) ?? 0.0
                }

                // ANE Power
                if let aneMatch = output.range(of: #"ANE Power: (\d+\.\d+)"#, options: .regularExpression) {
                    let valStr = output[aneMatch].split(separator: " ")[2]
                    anePower = Double(valStr) ?? 0.0
                }

                // CPU die temperature
                if let cpuTempMatch = output.range(of: #"CPU die temperature: (\d+\.\d+)"#, options: .regularExpression) {
                    let valStr = output[cpuTempMatch].split(separator: " ")[3]
                    cpuTemp = Double(valStr) ?? 0.0
                }

                // GPU die temperature
                if let gpuTempMatch = output.range(of: #"GPU die temperature: (\d+\.\d+)"#, options: .regularExpression) {
                    let valStr = output[gpuTempMatch].split(separator: " ")[3]
                    gpuTemp = Double(valStr) ?? 0.0
                }
            }

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
        // Placeholder implementation
        return (80.0, 150, false)
    }

    func updateBatteryControlState(_ state: BatteryControlState, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            print("Received new battery control state: Limit: \(state.chargeLimit), Sailing: \(state.sailingModeEnabled), Force Discharge: \(state.forceDischarge)")

            // SMCHelper.shared.writeKey("BCLM", value: state.chargeLimit)
            // SMCHelper.shared.writeKey("CH0I", value: state.forceDischarge ? 1 : 0)

            completion(true, nil)
        }
    }
}
