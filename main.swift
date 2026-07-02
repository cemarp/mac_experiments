import Foundation
import IOKit

func writeSMCKey(key: String, value: Int) -> Int32 {
    let masterPort: mach_port_t
    if #available(macOS 12.0, *) {
        masterPort = kIOMainPortDefault
    } else {
        masterPort = kIOMasterPortDefault
    }

    let service = IOServiceGetMatchingService(masterPort, IOServiceMatching("AppleSMC"))
    if service == 0 { return -1 }

    var connection: io_connect_t = 0
    let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
    IOObjectRelease(service)

    if result != kIOReturnSuccess { return result }

    print("Pretending to write to SMC via privileged utility tool: \(key) -> \(value)")

    IOServiceClose(connection)
    return kIOReturnSuccess
}

let args = CommandLine.arguments
if args.count == 3 {
    let key = args[1]
    if let value = Int(args[2]) {
        let result = writeSMCKey(key: key, value: value)
        if result == kIOReturnSuccess {
            print("Success")
            exit(0)
        } else {
            print("Error: \(result)")
            exit(1)
        }
    } else {
        print("Invalid value")
        exit(1)
    }
} else {
    print("Usage: smc_util <key> <value>")
    exit(1)
}
