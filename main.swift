import Foundation
import IOKit

enum SMCCommand: UInt8 {
    case kSMCUserClientOpen = 0
    case kSMCUserClientClose = 1
    case kSMCHandleYPCEvent = 2
    case kSMCReadKey = 5
    case kSMCWriteKey = 6
    case kSMCGetKeyCount = 7
    case kSMCGetKeyFromIndex = 8
    case kSMCGetKeyInfo = 9
}

func getFourCharCode(fromString string: String) -> UInt32 {
    var result: UInt32 = 0
    let data = string.data(using: .macOSRoman)!
    for (i, byte) in data.enumerated() {
        if i >= 4 { break }
        result = (result << 8) | UInt32(byte)
    }
    return result
}

func smcCall(connection: io_connect_t, command: SMCCommand, inputStruct: inout SMCParamStruct) -> Int32 {
    let inputSize = MemoryLayout<SMCParamStruct>.size
    var outputStruct = SMCParamStruct()
    var outputSize = MemoryLayout<SMCParamStruct>.size

    let result = IOConnectCallStructMethod(
        connection,
        UInt32(command.rawValue),
        &inputStruct,
        inputSize,
        &outputStruct,
        &outputSize
    )

    if result == kIOReturnSuccess {
        inputStruct = outputStruct
    }

    return result
}

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

    // We must call open user client first
    var openStruct = SMCParamStruct()
    openStruct.data8 = SMCCommand.kSMCUserClientOpen.rawValue
    _ = smcCall(connection: connection, command: .kSMCUserClientOpen, inputStruct: &openStruct)

    let fourCharCode = getFourCharCode(fromString: key)

    // First, get key info to determine size and type
    var inputStruct = SMCParamStruct()
    inputStruct.key = fourCharCode
    inputStruct.data8 = SMCCommand.kSMCGetKeyInfo.rawValue

    var callResult = smcCall(connection: connection, command: .kSMCHandleYPCEvent, inputStruct: &inputStruct)

    if callResult != kIOReturnSuccess || inputStruct.result != 0 {
        IOServiceClose(connection)
        return callResult == kIOReturnSuccess ? Int32(inputStruct.result) : callResult
    }

    let keyInfo = inputStruct.keyInfo

    // Now setup the write
    var writeStruct = SMCParamStruct()
    writeStruct.key = fourCharCode
    writeStruct.keyInfo = keyInfo
    writeStruct.data8 = SMCCommand.kSMCWriteKey.rawValue
    writeStruct.keyInfo.dataSize = keyInfo.dataSize

    // Convert Swift tuple to C array via pointer manipulation is messy.
    // However, Swift imports the 32-element array as a tuple. We can modify it via reflection or pointer casting.
    withUnsafeMutablePointer(to: &writeStruct.bytes) { bytesPtr in
        let rawPtr = UnsafeMutableRawPointer(bytesPtr).assumingMemoryBound(to: UInt8.self)
        let byteValue = UInt8(value & 0xFF)
        rawPtr[0] = byteValue
        if keyInfo.dataSize > 1 {
            rawPtr[1] = UInt8((value >> 8) & 0xFF)
        }
    }

    callResult = smcCall(connection: connection, command: .kSMCHandleYPCEvent, inputStruct: &writeStruct)

    IOServiceClose(connection)

    if callResult == kIOReturnSuccess && writeStruct.result != 0 {
        return Int32(writeStruct.result)
    }

    return callResult
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
