import Foundation
import IOKit

public struct FanInfo: Codable, Sendable {
    public let id: Int
    public let name: String
    public let actualRPM: Int
    public let minRPM: Int
    public let maxRPM: Int
    public let targetRPM: Int

    public init(id: Int, name: String, actualRPM: Int, minRPM: Int, maxRPM: Int, targetRPM: Int) {
        self.id = id
        self.name = name
        self.actualRPM = actualRPM
        self.minRPM = minRPM
        self.maxRPM = maxRPM
        self.targetRPM = targetRPM
    }
}

public enum FanMode: String, Codable, CaseIterable, Sendable {
    case off = "off"
    case auto = "auto"
    case boost = "boost"
    case high = "high"
    case max = "max"
}

public final class SMCController: @unchecked Sendable {
    public static let shared = SMCController()

    private let lock = NSLock()
    private var connection: io_connect_t = 0
    private var isOpen: Bool = false

    private struct SMCVersion {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }

    private struct SMCPLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    private struct SMCKeyInfoData {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    private struct SMCKeyData {
        var key: UInt32 = 0
        var vers = SMCVersion()
        var pLimitData = SMCPLimitData()
        var keyInfo = SMCKeyInfoData()
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }

    private let kSMCCmdReadBytes: UInt8 = 5
    private let kSMCCmdWriteBytes: UInt8 = 6
    private let kSMCCmdReadKeyInfo: UInt8 = 9
    private let kSMCKernelIndex: UInt32 = 2

    public init() {
        open()
    }

    deinit {
        close()
    }

    public var isAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isOpen
    }

    @discardableResult
    public func open() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if isOpen { return true }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        if service == 0 {
            return false
        }
        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        if result == kIOReturnSuccess {
            isOpen = true
            return true
        }
        return false
    }

    public func close() {
        lock.lock()
        defer { lock.unlock() }

        if isOpen && connection != 0 {
            IOServiceClose(connection)
            connection = 0
            isOpen = false
        }
    }

    private func fourCharCode(from string: String) -> UInt32 {
        var res: UInt32 = 0
        for byte in string.utf8.prefix(4) {
            res = (res << 8) | UInt32(byte)
        }
        return res
    }

    private func callSMC(input: inout SMCKeyData, output: inout SMCKeyData) -> kern_return_t {
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride

        return IOConnectCallStructMethod(
            connection,
            kSMCKernelIndex,
            &input,
            inputSize,
            &output,
            &outputSize
        )
    }

    private func readKey(_ keyStr: String) -> (bytes: [UInt8], type: UInt32)? {
        guard isOpen else { return nil }

        let key = fourCharCode(from: keyStr)
        var input = SMCKeyData()
        input.key = key
        input.data8 = kSMCCmdReadKeyInfo

        var output = SMCKeyData()
        var ret = callSMC(input: &input, output: &output)
        guard ret == kIOReturnSuccess else { return nil }

        let size = Int(output.keyInfo.dataSize)
        let type = output.keyInfo.dataType

        input.key = key
        input.keyInfo.dataSize = UInt32(size)
        input.data8 = kSMCCmdReadBytes

        ret = callSMC(input: &input, output: &output)
        guard ret == kIOReturnSuccess else { return nil }

        let mirror = Mirror(reflecting: output.bytes)
        let bytesArray = mirror.children.prefix(size).compactMap { $0.value as? UInt8 }
        return (bytesArray, type)
    }

    private func writeKey(_ keyStr: String, bytes: [UInt8]) -> Bool {
        guard isOpen else { return false }

        let key = fourCharCode(from: keyStr)
        var input = SMCKeyData()
        input.key = key
        input.data8 = kSMCCmdReadKeyInfo

        var output = SMCKeyData()
        var ret = callSMC(input: &input, output: &output)
        guard ret == kIOReturnSuccess else { return false }

        input.key = key
        input.keyInfo.dataSize = UInt32(bytes.count)
        input.data8 = kSMCCmdWriteBytes

        withUnsafeMutableBytes(of: &input.bytes) { ptr in
            for (i, b) in bytes.enumerated() {
                if i < ptr.count {
                    ptr[i] = b
                }
            }
        }

        ret = callSMC(input: &input, output: &output)
        return ret == kIOReturnSuccess && output.result == 0
    }

    // MARK: - Public Read / Write Operations

    public func getFanCount() -> Int {
        guard let res = readKey("FNum"), !res.bytes.isEmpty else {
            return 0
        }
        return Int(res.bytes[0])
    }

    public func getFanInfo(index: Int) -> FanInfo? {
        guard let actualData = readKey("F\(index)Ac") else { return nil }
        let actual = decodeFPE2(actualData.bytes)

        let minRPM = decodeFPE2(readKey("F\(index)Mn")?.bytes ?? [])
        let maxRPM = decodeFPE2(readKey("F\(index)Mx")?.bytes ?? [])
        let targetRPM = decodeFPE2(readKey("F\(index)Tg")?.bytes ?? [])

        return FanInfo(
            id: index,
            name: "Fan \(index + 1)",
            actualRPM: actual,
            minRPM: minRPM > 0 ? minRPM : 1200,
            maxRPM: maxRPM > 0 ? maxRPM : 6500,
            targetRPM: targetRPM
        )
    }

    public func getAllFans() -> [FanInfo] {
        let count = getFanCount()
        var fans: [FanInfo] = []
        for i in 0..<count {
            if let info = getFanInfo(index: i) {
                fans.append(info)
            }
        }
        return fans
    }

    public func getCPUTemperature() -> Double? {
        // Known CPU temperature keys across Intel and Apple Silicon
        let candidateKeys = [
            "TC0P", "TC0D", "TC0E", "TC0F", "TC1C", "TC2C", "TC3C", "TC4C",
            "Tp0P", "Tp0D", "Tm0P", "TG0P", "TG0D", "TPCD", "Te0t", "TC0c"
        ]

        var temps: [Double] = []
        for key in candidateKeys {
            if let data = readKey(key) {
                let temp = decodeSP78(data.bytes)
                if temp > 15.0 && temp < 115.0 {
                    temps.append(temp)
                }
            }
        }

        if !temps.isEmpty {
            // Return maximum temperature among CPU cores
            return temps.max()
        }
        return nil
    }

    public func setFanMode(_ mode: FanMode, customPercent: Int = 0) -> Bool {
        let fans = getAllFans()
        guard !fans.isEmpty else { return false }

        switch mode {
        case .auto:
            // Write 0 to FS! to restore system automatic fan management
            return writeKey("FS! ", bytes: [0x00, 0x00])

        case .off:
            // Set min fans
            _ = writeKey("FS! ", bytes: [0x01, 0x01])
            for fan in fans {
                _ = setFanTargetRPM(fanIndex: fan.id, rpm: fan.minRPM)
            }
            return true

        case .boost:
            // ~70% fan speed
            _ = writeKey("FS! ", bytes: [0x01, 0x01])
            for fan in fans {
                let rpm = fan.minRPM + Int(Double(fan.maxRPM - fan.minRPM) * 0.70)
                _ = setFanTargetRPM(fanIndex: fan.id, rpm: rpm)
            }
            return true

        case .high:
            // ~85% fan speed
            _ = writeKey("FS! ", bytes: [0x01, 0x01])
            for fan in fans {
                let rpm = fan.minRPM + Int(Double(fan.maxRPM - fan.minRPM) * 0.85)
                _ = setFanTargetRPM(fanIndex: fan.id, rpm: rpm)
            }
            return true

        case .max:
            // 100% max fans
            _ = writeKey("FS! ", bytes: [0x01, 0x01])
            for fan in fans {
                _ = setFanTargetRPM(fanIndex: fan.id, rpm: fan.maxRPM)
            }
            return true
        }
    }

    public func setFanTargetRPM(fanIndex: Int, rpm: Int) -> Bool {
        let count = getFanCount()
        guard fanIndex >= 0 && fanIndex < count else { return false }
        guard let info = getFanInfo(index: fanIndex) else { return false }
        let clampedRPM = max(info.minRPM, min(info.maxRPM, rpm))
        let bytes = encodeFPE2(clampedRPM)
        return writeKey("F\(fanIndex)Tg", bytes: bytes)
    }

    // MARK: - Decoders & Encoders

    /// Decode fpe2 format (14 bits integer, 2 bits fraction)
    private func decodeFPE2(_ bytes: [UInt8]) -> Int {
        guard bytes.count >= 2 else { return 0 }
        let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
        return Int(raw >> 2)
    }

    /// Encode fpe2 format
    private func encodeFPE2(_ rpm: Int) -> [UInt8] {
        let shifted = UInt16(clamping: rpm) << 2
        return [UInt8((shifted >> 8) & 0xFF), UInt8(shifted & 0xFF)]
    }

    /// Decode sp78 format (signed 8 bits integer, 8 bits fraction)
    private func decodeSP78(_ bytes: [UInt8]) -> Double {
        guard bytes.count >= 2 else { return 0.0 }
        let intPart = Double(Int8(bitPattern: bytes[0]))
        let fracPart = Double(bytes[1]) / 256.0
        return intPart + fracPart
    }
}

