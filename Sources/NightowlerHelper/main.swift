import Foundation
import NightowlerCore

final class HelperServiceDelegate: NSObject, NSXPCListenerDelegate, NightowlerHelperXPCProtocol {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: NightowlerHelperXPCProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    func setDisableSleep(_ disable: Bool, withReply reply: @escaping (Bool, String?) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-a", "disablesleep", disable ? "1" : "0"]
        let pipe = Pipe()
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                reply(true, nil)
            } else {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let err = String(data: data, encoding: .utf8) ?? "pmset error"
                reply(false, err)
            }
        } catch {
            reply(false, error.localizedDescription)
        }
    }

    func forceSleep(withReply reply: @escaping (Bool) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["sleepnow"]
        do {
            try task.run()
            task.waitUntilExit()
            reply(task.terminationStatus == 0)
        } catch {
            reply(false)
        }
    }

    func version(withReply reply: @escaping (String) -> Void) {
        reply("1.0.0")
    }

    func protocolVersion(withReply reply: @escaping (Int) -> Void) {
        reply(1)
    }

    func setFanPercent(_ percent: Int, withReply reply: @escaping (Bool) -> Void) {
        let mode: FanMode = percent > 85 ? .max : (percent > 65 ? .high : (percent > 40 ? .boost : .auto))
        let ok = SMCController.shared.setFanMode(mode)
        reply(ok)
    }

    func setFanAuto(withReply reply: @escaping (Bool) -> Void) {
        let ok = SMCController.shared.setFanMode(.auto)
        reply(ok)
    }

    func setMaxFans(withReply reply: @escaping (Bool) -> Void) {
        let ok = SMCController.shared.setFanMode(.max)
        reply(ok)
    }

    func heartbeat(withReply reply: @escaping (Bool) -> Void) {
        reply(true)
    }
}

let delegate = HelperServiceDelegate()
let listener = NSXPCListener(machServiceName: HelperClient.machServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
