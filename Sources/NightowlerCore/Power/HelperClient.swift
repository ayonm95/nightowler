import Foundation

@objc public protocol NightowlerHelperXPCProtocol {
    func setDisableSleep(_ disable: Bool, withReply reply: @escaping (Bool, String?) -> Void)
    func forceSleep(withReply reply: @escaping (Bool) -> Void)
    func version(withReply reply: @escaping (String) -> Void)
    func protocolVersion(withReply reply: @escaping (Int) -> Void)
    func setFanPercent(_ percent: Int, withReply reply: @escaping (Bool) -> Void)
    func setFanAuto(withReply reply: @escaping (Bool) -> Void)
    func setMaxFans(withReply reply: @escaping (Bool) -> Void)
    func heartbeat(withReply reply: @escaping (Bool) -> Void)
}

public final class HelperClient: @unchecked Sendable {
    public static let shared = HelperClient()

    public static let machServiceName = "com.nightowler.app.helper"
    private let lock = NSLock()
    private var connection: NSXPCConnection?

    public init() {}

    public var isHelperAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }

        // Test if connection works
        let conn = getConnectionLocked()
        var available = false
        let sema = DispatchSemaphore(value: 0)

        guard let proxy = conn.remoteObjectProxyWithErrorHandler({ _ in
            sema.signal()
        }) as? NightowlerHelperXPCProtocol else {
            return false
        }

        proxy.version { version in
            if !version.isEmpty {
                available = true
            }
            sema.signal()
        }

        _ = sema.wait(timeout: .now() + 0.3)
        return available
    }

    private func getConnectionLocked() -> NSXPCConnection {
        if let existing = connection {
            return existing
        }

        let conn = NSXPCConnection(machServiceName: HelperClient.machServiceName)
        conn.remoteObjectInterface = NSXPCInterface(with: NightowlerHelperXPCProtocol.self)
        conn.invalidationHandler = { [weak self] in
            self?.lock.lock()
            self?.connection = nil
            self?.lock.unlock()
        }
        conn.interruptionHandler = { [weak self] in
            self?.lock.lock()
            self?.connection = nil
            self?.lock.unlock()
        }
        conn.resume()
        connection = conn
        return conn
    }

    public func setDisableSleep(_ disable: Bool) -> (success: Bool, error: String?) {
        lock.lock()
        let conn = getConnectionLocked()
        lock.unlock()

        var resultSuccess = false
        var resultError: String? = nil
        let sema = DispatchSemaphore(value: 0)

        guard let proxy = conn.remoteObjectProxyWithErrorHandler({ err in
            resultError = err.localizedDescription
            sema.signal()
        }) as? NightowlerHelperXPCProtocol else {
            return (false, "Could not obtain helper proxy")
        }

        proxy.setDisableSleep(disable) { success, err in
            resultSuccess = success
            resultError = err
            sema.signal()
        }

        _ = sema.wait(timeout: .now() + 2.0)
        return (resultSuccess, resultError)
    }

    public func forceSleep() -> (success: Bool, error: String?) {
        lock.lock()
        let conn = getConnectionLocked()
        lock.unlock()

        var resultSuccess = false
        var resultError: String? = nil
        let sema = DispatchSemaphore(value: 0)

        guard let proxy = conn.remoteObjectProxyWithErrorHandler({ err in
            resultError = err.localizedDescription
            sema.signal()
        }) as? NightowlerHelperXPCProtocol else {
            return (false, "Could not obtain helper proxy")
        }

        proxy.forceSleep { success in
            resultSuccess = success
            sema.signal()
        }

        _ = sema.wait(timeout: .now() + 2.0)
        return (resultSuccess, resultError)
    }

    public func setFanPercent(_ percent: Int) -> Bool {
        lock.lock()
        let conn = getConnectionLocked()
        lock.unlock()

        var result = false
        let sema = DispatchSemaphore(value: 0)

        guard let proxy = conn.remoteObjectProxyWithErrorHandler({ _ in
            sema.signal()
        }) as? NightowlerHelperXPCProtocol else {
            return false
        }

        proxy.setFanPercent(percent) { ok in
            result = ok
            sema.signal()
        }

        _ = sema.wait(timeout: .now() + 1.0)
        return result
    }

    public func setFanAuto() -> Bool {
        lock.lock()
        let conn = getConnectionLocked()
        lock.unlock()

        var result = false
        let sema = DispatchSemaphore(value: 0)

        guard let proxy = conn.remoteObjectProxyWithErrorHandler({ _ in
            sema.signal()
        }) as? NightowlerHelperXPCProtocol else {
            return false
        }

        proxy.setFanAuto { ok in
            result = ok
            sema.signal()
        }

        _ = sema.wait(timeout: .now() + 1.0)
        return result
    }
}
