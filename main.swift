import Foundation
import IOKit

public struct SMCVersion {
    var major: CUnsignedChar
    var minor: CUnsignedChar
    var build: CUnsignedChar
    var reserved: CUnsignedChar
    var release: CUnsignedShort
}

public struct SMCPLimitData {
    var version: UInt16
    var length: UInt16
    var cpuPLimit: UInt32
    var gpuPLimit: UInt32
    var memPLimit: UInt32
}

public struct SMCKeyInfoData {
    var dataSize: IOByteCount
    var dataType: UInt32
    var dataAttributes: UInt8
}

public struct SMCParamStruct {
    var key: UInt32
    var vers: SMCVersion
    var pLimitData: SMCPLimitData
    var keyInfo: SMCKeyInfoData
    var result: UInt8
    var status: UInt8
    var data8: UInt8
    var data32: UInt32
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
}

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
    var outputStruct = SMCParamStruct(
        key: 0,
        vers: SMCVersion(major: 0, minor: 0, build: 0, reserved: 0, release: 0),
        pLimitData: SMCPLimitData(version: 0, length: 0, cpuPLimit: 0, gpuPLimit: 0, memPLimit: 0),
        keyInfo: SMCKeyInfoData(dataSize: 0, dataType: 0, dataAttributes: 0),
        result: 0,
        status: 0,
        data8: 0,
        data32: 0,
        bytes: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    )
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

    let fourCharCode = getFourCharCode(fromString: key)

    // First, get key info to determine size and type
    var inputStruct = SMCParamStruct(
        key: fourCharCode,
        vers: SMCVersion(major: 0, minor: 0, build: 0, reserved: 0, release: 0),
        pLimitData: SMCPLimitData(version: 0, length: 0, cpuPLimit: 0, gpuPLimit: 0, memPLimit: 0),
        keyInfo: SMCKeyInfoData(dataSize: 0, dataType: 0, dataAttributes: 0),
        result: 0,
        status: 0,
        data8: 0,
        data32: 0,
        bytes: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    )

    inputStruct.data8 = SMCCommand.kSMCGetKeyInfo.rawValue
    var callResult = smcCall(connection: connection, command: .kSMCHandleYPCEvent, inputStruct: &inputStruct)

    if callResult != kIOReturnSuccess || inputStruct.result != 0 {
        IOServiceClose(connection)
        return callResult == kIOReturnSuccess ? Int32(inputStruct.result) : callResult
    }

    let keyInfo = inputStruct.keyInfo

    // Now setup the write
    inputStruct.keyInfo.dataSize = keyInfo.dataSize

    // We assume data is simply a single integer byte for these specific keys
    let byteValue = UInt8(value & 0xFF)
    inputStruct.bytes.0 = byteValue

    inputStruct.data8 = SMCCommand.kSMCWriteKey.rawValue

    callResult = smcCall(connection: connection, command: .kSMCHandleYPCEvent, inputStruct: &inputStruct)

    IOServiceClose(connection)

    if callResult == kIOReturnSuccess && inputStruct.result != 0 {
        return Int32(inputStruct.result)
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
