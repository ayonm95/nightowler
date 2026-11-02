import Foundation
import NightowlerCore

func printHelp() {
    print("""
nightowler — Autonomous macOS Background Workload & Nocturnal Clamshell Guardian

Usage:
  nightowler -- <cmd> [args...]   Wrap a command (standalone sleep prevention).
                                  System stays awake until the command terminates.

Daemon commands (Nightowler menu app running):
  nightowler status [--json]      Display active power, thermal, and workload state
  nightowler start [seconds]      Manual keep-awake session (optional duration)
  nightowler stop                 Stop active keep-awake & release clamshell lock
  nightowler clamshell [on|off]   Enable/disable closed-lid execution mode
  nightowler autowatch [on|off]   Auto Mode: keep awake only while workloads run
  nightowler fan <off|auto|boost|high|max>
                                  Hardware fan cooling profile via AppleSMC
  nightowler watch <pattern...>   Add process patterns to auto-watch list
  nightowler unwatch <pattern...> Remove process patterns from watch list
  nightowler patterns             List currently watched process patterns
  nightowler timer <seconds>      Set keep-awake duration in seconds
  nightowler notify "<title>" ["<body>"]
                                  Dispatch local alert & configured webhooks
  nightowler sleep [--force]      Put Mac to sleep safely. Refuses if tasks run;
                                  --force overrides active process check.

Examples:
  nightowler -- python train.py --epochs 100
  nightowler -- docker compose up --build
  nightowler status --json
  nightowler fan boost
  nightowler autowatch on
  nightowler watch ollama vllm whisper
  nightowler timer 3600
""")
}

func runWrappedCommand(args: [String]) -> Int32 {
    guard !args.isEmpty else {
        print("Error: No command specified to run. Usage: nightowler -- <command> [args...]")
        return 1
    }

    // Attempt to notify daemon first, and initialize direct IOKit assertion
    let client = IPCClient.shared
    _ = client.send(request: IPCRequest(cmd: "start"))

    let power = PowerAssertionManager()
    let held = power.createSystemAssertion(reason: "nightowler -- \(args.joined(separator: " "))")
    if !held {
        fputs("Warning: Could not create system power assertion, executing command anyway.\n", stderr)
    }

    let proc = Process()
    let cmd = args[0]
    if cmd.contains("/") {
        proc.executableURL = URL(fileURLWithPath: cmd)
    } else {
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = args
    }

    if proc.executableURL?.path != "/usr/bin/env" {
        proc.arguments = Array(args.dropFirst())
    }

    // Forward standard I/O
    proc.standardInput = FileHandle.standardInput
    proc.standardOutput = FileHandle.standardOutput
    proc.standardError = FileHandle.standardError

    // Gracefully handle signals
    signal(SIGINT) { _ in }
    signal(SIGTERM) { _ in }

    do {
        try proc.run()
        proc.waitUntilExit()
        power.releaseAll()
        _ = client.send(request: IPCRequest(cmd: "stop"))
        return proc.terminationStatus
    } catch {
        power.releaseAll()
        _ = client.send(request: IPCRequest(cmd: "stop"))
        fputs("Failed to execute command: \(error.localizedDescription)\n", stderr)
        return 127
    }
}

func sendDaemonCommand(req: IPCRequest) -> IPCResponse? {
    let client = IPCClient.shared
    if let resp = client.send(request: req) {
        return resp
    }
    print("Nightowler daemon is not running. Launch Nightowler.app first.")
    return nil
}

func formatStatusHuman(_ resp: IPCResponse) {
    print("--- Nightowler System Status ---")
    print("Mode:                 \(resp.mode?.capitalized ?? "Off")")
    print("Keep-Awake Active:    \(resp.assertionActive == true ? "YES" : "No")")
    print("Clamshell Guard:      \(resp.clamshellActive == true ? "YES" : "No")")
    print("Status:               \(resp.whyAwake ?? "Mac sleeping normally")")
    if let ws = resp.whyStopped, !ws.isEmpty {
        print("Reason Stopped:       \(ws)")
    }
    print("Battery:              \(resp.batteryPercent ?? 0)% (\(resp.isCharging == true ? "AC Power" : "Battery Reserve"))")
    print("Thermal State:        \(resp.thermal?.capitalized ?? "Nominal")")
    if let temp = resp.temperatureCelsius {
        print("CPU Temperature:      \(Int(temp))°C")
    }
    print("Cooling Profile:      \(resp.coolingMode?.capitalized ?? "Auto")")
    if let rpms = resp.fanRPMs, !rpms.isEmpty {
        let rpmStrs = rpms.enumerated().map { "Fan \($0 + 1): \($1) RPM" }.joined(separator: ", ")
        print("Fan Speeds:           \(rpmStrs)")
    }
    if let tasks = resp.tasks, !tasks.isEmpty {
        print("Active Workloads:     \(tasks.joined(separator: ", "))")
    } else {
        print("Active Workloads:     None")
    }
}

// MARK: - CLI Entry Point

let args = Array(CommandLine.arguments.dropFirst())

if args.isEmpty || args.contains("-h") || args.contains("--help") || args.first == "help" {
    printHelp()
    exit(0)
}

if args.first == "--" {
    let subArgs = Array(args.dropFirst())
    let code = runWrappedCommand(args: subArgs)
    exit(code)
}

let command = args[0].lowercased()

switch command {
case "status":
    guard let resp = sendDaemonCommand(req: IPCRequest(cmd: "status")) else { exit(1) }
    if args.contains("--json") {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(resp), let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    } else {
        formatStatusHuman(resp)
    }

case "start":
    let seconds = args.count > 1 ? Int(args[1]) : nil
    guard let resp = sendDaemonCommand(req: IPCRequest(cmd: "start", seconds: seconds)) else { exit(1) }
    print(resp.message ?? "OK")

case "stop":
    guard let resp = sendDaemonCommand(req: IPCRequest(cmd: "stop")) else { exit(1) }
    print(resp.message ?? "OK")

case "clamshell":
    let sub = args.count > 1 ? args[1] : "toggle"
    guard let resp = sendDaemonCommand(req: IPCRequest(cmd: "clamshell", args: [sub])) else { exit(1) }
    print(resp.message ?? "OK")

case "autowatch":
    let sub = args.count > 1 ? args[1] : "toggle"
    guard let resp = sendDaemonCommand(req: IPCRequest(cmd: "autowatch", args: [sub])) else { exit(1) }
    print(resp.message ?? "OK")

case "timer":
    guard args.count > 1, let secs = Int(args[1]), secs > 0 else {
        print("Usage: nightowler timer <seconds>")
        exit(1)
    }
    guard let resp = sendDaemonCommand(req: IPCRequest(cmd: "timer", seconds: secs)) else { exit(1) }
    print(resp.message ?? "OK")

case "watch":
    let patterns = Array(args.dropFirst())
    guard !patterns.isEmpty else {
        print("Usage: nightowler watch <pattern...>")
        exit(1)
    }
    guard let resp = sendDaemonCommand(req: IPCRequest(cmd: "watch", patterns: patterns)) else { exit(1) }
    print(resp.message ?? "OK")

case "unwatch":
    let patterns = Array(args.dropFirst())
    guard !patterns.isEmpty else {
        print("Usage: nightowler unwatch <pattern...>")
        exit(1)
    }
    guard let resp = sendDaemonCommand(req: IPCRequest(cmd: "unwatch", patterns: patterns)) else { exit(1) }
    print(resp.message ?? "OK")

case "patterns":
    guard let resp = sendDaemonCommand(req: IPCRequest(cmd: "patterns")) else { exit(1) }
    if let pats = resp.patterns {
        print("Watched Patterns (\(pats.count)):")
        for p in pats {
            print("  • \(p)")
        }
    }

case "fan":
    guard args.count > 1 else {
        print("Usage: nightowler fan <off|auto|boost|high|max>")
        exit(1)
    }
    let mode = args[1]
    guard let resp = sendDaemonCommand(req: IPCRequest(cmd: "fan", mode: mode)) else { exit(1) }
    print(resp.message ?? "OK")

case "sleep":
    let force = args.contains("--force")
    guard let resp = sendDaemonCommand(req: IPCRequest(cmd: "sleep", force: force)) else { exit(1) }
    if resp.ok {
        print(resp.message ?? "Mac entering sleep mode...")
    } else {
        print("Error: \(resp.message ?? "Failed to initiate sleep")")
        exit(1)
    }

case "notify":
    guard args.count > 1 else {
        print("Usage: nightowler notify \"<title>\" [\"<body>\"]")
        exit(1)
    }
    let title = args[1]
    let body = args.count > 2 ? args[2] : ""
    guard let resp = sendDaemonCommand(req: IPCRequest(cmd: "notify", title: title, body: body)) else { exit(1) }
    print(resp.message ?? "OK")

case "ping":
    guard let resp = sendDaemonCommand(req: IPCRequest(cmd: "ping")) else { exit(1) }
    print(resp.message ?? "pong")

default:
    print("Unknown command: \(command). Run `nightowler help` for usage.")
    exit(1)
}
