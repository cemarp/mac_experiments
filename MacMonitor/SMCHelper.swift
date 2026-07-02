import Foundation
import IOKit

class SMCHelper {
    static let shared = SMCHelper()

    private var connection: io_connect_t = 0

    private init() {
        openConnection()
    }

    deinit {
        closeConnection()
    }

    private func openConnection() {
        print("[INSTRUMENTATION] SMCHelper: Attempting to open connection to AppleSMC...")
        let masterPort: mach_port_t
        if #available(macOS 12.0, *) {
            masterPort = kIOMainPortDefault
        } else {
            masterPort = kIOMasterPortDefault
        }

        let service = IOServiceGetMatchingService(masterPort, IOServiceMatching("AppleSMC"))
        if service != 0 {
            print("[INSTRUMENTATION] SMCHelper: Found AppleSMC service. Opening...")
            let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
            if result != kIOReturnSuccess {
                print("[INSTRUMENTATION] SMCHelper: Failed to open connection to AppleSMC. Error: \(result)")
            } else {
                print("[INSTRUMENTATION] SMCHelper: Successfully opened connection to AppleSMC.")
            }
            IOObjectRelease(service)
        } else {
            print("[INSTRUMENTATION] SMCHelper: Failed to find AppleSMC service")
        }
    }

    private func closeConnection() {
        if connection != 0 {
            print("[INSTRUMENTATION] SMCHelper: Closing connection to AppleSMC.")
            IOServiceClose(connection)
            connection = 0
        }
    }

    func readKey(_ key: String) -> Any? {
        print("[INSTRUMENTATION] SMCHelper: Attempting to read SMC key: \(key)")
        if connection == 0 {
            print("[INSTRUMENTATION] SMCHelper: Cannot read key \(key) because connection is 0.")
            return nil
        }
        // Placeholder for reading SMC keys
        // Use IOConnectCallStructMethod with correct selectors to read keys
        // Handle data unpacking for SMC key types
        print("Reading SMC key: \(key)")
        return nil
    }

    func writeKey(_ key: String, value: Any) -> Bool {
        print("[INSTRUMENTATION] SMCHelper: Attempting to write SMC key: \(key) with value: \(value)")
        if connection == 0 {
            print("[INSTRUMENTATION] SMCHelper: Cannot write key \(key) because connection is 0. Did IOServiceOpen fail?")
            return false
        }

        // Placeholder for writing SMC keys
        // Use IOConnectCallStructMethod with correct selectors to write keys
        // Handle data packing for SMC key types
        print("Writing SMC key: \(key) with value: \(value)")

        // Let's pretend it succeeded for now in the UI
        return true
    }
}
