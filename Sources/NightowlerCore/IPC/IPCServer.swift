import Foundation

public struct IPCRequest: Codable, Sendable {
    public let cmd: String
    public let args: [String]?
    public let seconds: Int?
    public let title: String?
    public let body: String?
    public let patterns: [String]?
    public let mode: String?
    public let force: Bool?

    public init(
        cmd: String,
        args: [String]? = nil,
        seconds: Int? = nil,
        title: String? = nil,
        body: String? = nil,
        patterns: [String]? = nil,
        mode: String? = nil,
        force: Bool? = nil
    ) {
        self.cmd = cmd
        self.args = args
        self.seconds = seconds
        self.title = title
        self.body = body
        self.patterns = patterns
        self.mode = mode
        self.force = force
    }
}

public struct IPCResponse: Codable, Sendable {
    public let ok: Bool
    public let message: String?
    public let mode: String?
    public let assertionActive: Bool?
    public let clamshellActive: Bool?
    public let batteryPercent: Int?
    public let isCharging: Bool?
    public let thermal: String?
    public let temperatureCelsius: Double?
    public let tasks: [String]?
    public let patterns: [String]?
    public let coolingMode: String?
    public let fanControlSupported: Bool?
    public let fanRPMs: [Int]?
    public let whyAwake: String?
    public let whyStopped: String?

    public init(
        ok: Bool,
        message: String? = nil,
        mode: String? = nil,
        assertionActive: Bool? = nil,
        clamshellActive: Bool? = nil,
        batteryPercent: Int? = nil,
        isCharging: Bool? = nil,
        thermal: String? = nil,
        temperatureCelsius: Double? = nil,
        tasks: [String]? = nil,
        patterns: [String]? = nil,
        coolingMode: String? = nil,
        fanControlSupported: Bool? = nil,
        fanRPMs: [Int]? = nil,
        whyAwake: String? = nil,
        whyStopped: String? = nil
    ) {
        self.ok = ok
        self.message = message
        self.mode = mode
        self.assertionActive = assertionActive
        self.clamshellActive = clamshellActive
        self.batteryPercent = batteryPercent
        self.isCharging = isCharging
        self.thermal = thermal
        self.temperatureCelsius = temperatureCelsius
        self.tasks = tasks
        self.patterns = patterns
        self.coolingMode = coolingMode
        self.fanControlSupported = fanControlSupported
        self.fanRPMs = fanRPMs
        self.whyAwake = whyAwake
        self.whyStopped = whyStopped
    }
}

public final class IPCServer: @unchecked Sendable {
    public static let shared = IPCServer()

    public static let socketPath = "/tmp/nightowler.sock"
    private var listenSource: DispatchSourceRead?
    private var listenFD: Int32 = -1
    private let queue = DispatchQueue(label: "com.nightowler.ipcserver", qos: .userInitiated)

    public var onRequest: ((IPCRequest) -> IPCResponse)?

    public init() {}

    public func start() {
        unlink(IPCServer.socketPath)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            print("Failed to create IPC socket")
            return
        }
        listenFD = fd

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let maxLen = MemoryLayout.size(ofValue: addr.sun_path)
        let pathBytes = IPCServer.socketPath.utf8CString
        guard pathBytes.count <= maxLen else {
            print("Socket path too long")
            close(fd)
            return
        }

        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: maxLen) { dest in
                _ = pathBytes.withUnsafeBufferPointer { src in
                    strncpy(dest, src.baseAddress!, maxLen)
                }
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        var bindRes: Int32 = -1
        withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bindRes = bind(fd, sa, addrLen)
            }
        }

        guard bindRes == 0 else {
            print("Failed to bind IPC socket: \(errno)")
            close(fd)
            return
        }

        // Set socket permissions for current user
        chmod(IPCServer.socketPath, 0o600)

        guard listen(fd, 16) == 0 else {
            print("Failed to listen on IPC socket: \(errno)")
            close(fd)
            return
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptConnection()
        }
        source.resume()
        listenSource = source
    }

    public func stop() {
        listenSource?.cancel()
        listenSource = nil
        if listenFD >= 0 {
            close(listenFD)
            listenFD = -1
        }
        unlink(IPCServer.socketPath)
    }

    private func acceptConnection() {
        var clientAddr = sockaddr_un()
        var clientLen = socklen_t(MemoryLayout<sockaddr_un>.size)

        let clientFD = withUnsafeMutablePointer(to: &clientAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                accept(listenFD, sa, &clientLen)
            }
        }

        guard clientFD >= 0 else { return }

        queue.async { [weak self] in
            self?.handleClient(fd: clientFD)
        }
    }

    private func handleClient(fd: Int32) {
        defer { close(fd) }

        var buffer = [UInt8](repeating: 0, count: 16384)
        let bytesRead = read(fd, &buffer, buffer.count)
        guard bytesRead > 0 else { return }

        let data = Data(buffer.prefix(bytesRead))
        guard let request = try? JSONDecoder().decode(IPCRequest.self, from: data) else {
            let errResp = IPCResponse(ok: false, message: "Invalid request payload")
            if let outData = try? JSONEncoder().encode(errResp) {
                _ = outData.withUnsafeBytes { ptr in
                    write(fd, ptr.baseAddress, outData.count)
                }
            }
            return
        }

        let response = onRequest?(request) ?? IPCResponse(ok: true, message: "OK")
        if let outData = try? JSONEncoder().encode(response) {
            _ = outData.withUnsafeBytes { ptr in
                write(fd, ptr.baseAddress, outData.count)
            }
        }
    }
}
