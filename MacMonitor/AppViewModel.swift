import Foundation
import Combine

class AppViewModel: ObservableObject {
    @Published var metricsHistory: [SystemMetrics] = []
    @Published var currentMetrics: SystemMetrics?

    @Published var batteryState = BatteryControlState() {
        didSet {
            sendBatteryStateToMonitor()
        }
    }

    private var timer: Timer?
    private let monitor = LocalSystemMonitor.shared

    // 7 days worth of data, assuming 1 sample every 5 seconds
    // 7 * 24 * 60 * 12 = 120,960 samples max in RAM. This is fine for a modern Mac.
    private let maxHistoryCount = 120960

    init() {
        startMonitoring()
    }

    private func startMonitoring() {
        timer?.invalidate()
        // Poll every 5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.fetchData()
        }
        fetchData() // Initial fetch
    }

    private func fetchData() {
        monitor.getMetrics { [weak self] metrics, error in
            guard let self = self, let metrics = metrics, error == nil else {
                if let error = error {
                    print("Error fetching metrics: \(error)")
                }
                return
            }

            DispatchQueue.main.async {
                self.currentMetrics = metrics
                self.metricsHistory.append(metrics)

                if self.metricsHistory.count > self.maxHistoryCount {
                    self.metricsHistory.removeFirst()
                }

                self.evaluateSailingMode(currentLevel: metrics.batteryLevel)
            }
        }
    }

    private func evaluateSailingMode(currentLevel: Double) {
        guard batteryState.sailingModeEnabled else { return }

        let upper = Double(batteryState.chargeLimit)
        let lower = Double(batteryState.sailingModeLowerLimit)

        // Basic state machine for Sailing Mode
        if currentLevel >= upper && !batteryState.forceDischarge {
            // Reached top, start sailing (inhibit charging/force discharge)
            batteryState.forceDischarge = true
        } else if currentLevel <= lower && batteryState.forceDischarge {
            // Reached bottom, stop sailing (resume charging)
            batteryState.forceDischarge = false
        }
    }

    private func sendBatteryStateToMonitor() {
        monitor.updateBatteryControlState(batteryState) { success, error in
            if let error = error {
                print("Failed to update battery state: \(error)")
            }
        }
    }
}
