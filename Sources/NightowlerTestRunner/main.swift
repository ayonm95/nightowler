import Foundation
import NightowlerCore

func assertTest(_ condition: Bool, _ message: String) {
    if condition {
        print("  ✅ PASS: \(message)")
    } else {
        print("  ❌ FAIL: \(message)")
        exit(1)
    }
}

print("=== Running Nightowler Verification Suite ===")

// Test 1: Native Engine Capabilities
print("\n[1] Testing Native Engine Capabilities")
let caps = EngineCapabilities.shared
assertTest(caps.fanControlSupported, "Hardware fan control capability active")
assertTest(caps.autoModeEnabled, "Autonomous workload watcher active")
assertTest(caps.closedLidGuarded, "Guarded clamshell execution active")
assertTest(caps.smartRulesEnabled, "Reactive rules engine active")
assertTest(caps.webhooksEnabled, "Multi-channel webhook dispatch active")
assertTest(caps.activityLoggingEnabled, "In-memory audit logging active")
assertTest(caps.unlimitedSessions, "Continuous session mode active")

// Test 2: Power Assertion Manager
print("\n[2] Testing Power Assertion Manager")
let power = PowerAssertionManager()
assertTest(!power.holdsSystemAssertion, "Initially holds no system assertion")
let held = power.createSystemAssertion(reason: "Nightowler Test Run")
assertTest(held, "Successfully created system power assertion")
assertTest(power.holdsSystemAssertion, "holdsSystemAssertion is true")
power.releaseSystemAssertion()
assertTest(!power.holdsSystemAssertion, "Successfully released system power assertion")

// Test 3: Rules Store & Built-in Rules
print("\n[3] Testing Rules Store")
let store = RulesStore.shared
let rules = store.rules
assertTest(!rules.isEmpty, "Rules list is populated")
assertTest(rules.contains { $0.builtinKey == "builtin.claude-code" }, "Contains Claude Code rule")
assertTest(rules.contains { $0.builtinKey == "builtin.cursor" }, "Contains Cursor rule")
assertTest(rules.contains { $0.builtinKey == "builtin.docker" }, "Contains Docker rule")
assertTest(rules.contains { $0.builtinKey == "builtin.battery-sleep-5" }, "Contains Battery sleep rule")

// Test 4: Rule Engine Evaluation
print("\n[4] Testing Rule Engine Evaluation")
let engine = RuleEngine.shared
var firedRule: Rule? = nil
engine.onPerformAction = { action, rule in
    firedRule = rule
}
// Ensure rule cooldown is cleared for idempotent test execution
for var r in store.rules {
    r.lastTriggeredAt = nil
    store.updateRule(r)
}
let batLow = BatterySnapshot(percent: 4, isCharging: false, isCharged: false, isOnACPower: false, hasBattery: true)
let thermal = ThermalSnapshot(level: .nominal, temperatureCelsius: 45.0)
engine.evaluate(battery: batLow, thermal: thermal, activeTasks: [], lastActiveWorkloadTime: Date())
assertTest(firedRule?.builtinKey == "builtin.battery-sleep-5", "Rule builtin.battery-sleep-5 triggered at 4% battery")

// Test 5: AppState Rule Action Execution Handler
print("\n[5] Testing AppState Rule Action Handler")
let appState = AppState.shared
let testRule = Rule(
    name: "Test Action Rule",
    isEnabled: true,
    isBuiltIn: false,
    actions: [.startKeepAwake, .setCoolingPreset("boost")]
)
appState.handleRuleAction(.startKeepAwake, rule: testRule)
assertTest(appState.mode == .on, "Rule action .startKeepAwake sets AppState mode to .on")
appState.handleRuleAction(.setCoolingPreset("boost"), rule: testRule)
assertTest(appState.coolingMode == .boost, "Rule action .setCoolingPreset('boost') sets coolingMode to .boost")
appState.setMode(.off)

// Test 6: Process Watcher
print("\n[6] Testing Process Watcher")
let watcher = ProcessWatcher.shared
let pats = watcher.patterns
assertTest(pats.contains("claude"), "Default patterns contain 'claude'")
assertTest(pats.contains("cursor"), "Default patterns contain 'cursor'")
assertTest(pats.contains("python"), "Default patterns contain 'python'")
watcher.addPattern("testtoolxyz")
assertTest(watcher.patterns.contains("testtoolxyz"), "Added 'testtoolxyz'")
watcher.removePattern("testtoolxyz")
assertTest(!watcher.patterns.contains("testtoolxyz"), "Removed 'testtoolxyz'")

// Test 7: Activity Log
print("\n[7] Testing Activity Log")
let log = ActivityLog.shared
log.clear()
assertTest(log.events.isEmpty, "Log cleared successfully")
log.logEvent(kind: "test_action", text: "Unit test action", value: 99.0)
assertTest(log.events.count == 1, "Logged 1 event")
assertTest(log.events.first?.kind == "test_action", "Event kind matches")
assertTest(log.events.first?.value == 99.0, "Event value matches")

// Test 8: IPC Request / Response Serialization
print("\n[8] Testing IPC Serialization")
let req = IPCRequest(cmd: "status", args: ["--json"], seconds: 1200)
let reqData = try! JSONEncoder().encode(req)
let reqDecoded = try! JSONDecoder().decode(IPCRequest.self, from: reqData)
assertTest(reqDecoded.cmd == "status" && reqDecoded.seconds == 1200, "IPCRequest serialized and deserialized correctly")

let resp = IPCResponse(ok: true, message: "OK", mode: "autoWatch", batteryPercent: 95, fanControlSupported: true)
let respData = try! JSONEncoder().encode(resp)
let respDecoded = try! JSONDecoder().decode(IPCResponse.self, from: respData)
assertTest(respDecoded.ok && respDecoded.mode == "autoWatch" && respDecoded.batteryPercent == 95 && respDecoded.fanControlSupported == true, "IPCResponse serialized and deserialized correctly")

// Test 9: Webhook Configuration Serialization
print("\n[9] Testing Webhook Configuration Serialization")
var whConfig = WebhookConfig()
whConfig.discordEnabled = true
whConfig.discordWebhookURL = "https://discord.com/api/webhooks/test"
let whData = try! JSONEncoder().encode(whConfig)
let whDecoded = try! JSONDecoder().decode(WebhookConfig.self, from: whData)
assertTest(whDecoded.discordEnabled && whDecoded.discordWebhookURL.contains("discord.com"), "WebhookConfig roundtrip successful")

// Test 10: SMC & Hardware Interface
print("\n[10] Testing SMC & Hardware")
let smc = SMCController.shared
print("  ℹ️ SMC Available: \(smc.isAvailable), Fan Count: \(smc.getFanCount()), CPU Temp: \(smc.getCPUTemperature() ?? 0)°C")
assertTest(true, "Hardware query completed without crashes")

print("\n🎉 ALL TESTS PASSED! Nightowler verification 100% complete.")
