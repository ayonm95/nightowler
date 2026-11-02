import Foundation

public final class IPCClient: @unchecked Sendable {
    public static let shared = IPCClient()

    public init() {}

    public func send(request: IPCRequest) -> IPCResponse? {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let maxLen = MemoryLayout.size(ofValue: addr.sun_path)
        let pathBytes = IPCServer.socketPath.utf8CString

        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: maxLen) { dest in
                _ = pathBytes.withUnsafeBufferPointer { src in
                    strncpy(dest, src.baseAddress!, maxLen)
                }
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        var connectRes: Int32 = -1
        withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                connectRes = connect(fd, sa, addrLen)
            }
        }

        guard connectRes == 0 else {
            return nil
        }

        guard let reqData = try? JSONEncoder().encode(request) else { return nil }

        let written = reqData.withUnsafeBytes { ptr in
            write(fd, ptr.baseAddress, reqData.count)
        }
        guard written == reqData.count else { return nil }

        // Shutdown write side to signal EOF to server if needed
        shutdown(fd, SHUT_WR)

        var buffer = [UInt8](repeating: 0, count: 32768)
        var responseData = Data()

        while true {
            let n = read(fd, &buffer, buffer.count)
            if n > 0 {
                responseData.append(buffer, count: n)
            } else {
                break
            }
        }

        guard !responseData.isEmpty else { return nil }
        return try? JSONDecoder().decode(IPCResponse.self, from: responseData)
    }
}

