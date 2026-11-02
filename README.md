# 🦉 Nightowler

> **Autonomous macOS Background Workload & Nocturnal Clamshell Guardian**  
> *Engineered natively in Swift 5.9+ for developers running local AI coding agents, LLM inference, Docker clusters, and long-running compilations with the MacBook lid closed.*

[![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-000000.svg?style=flat&logo=apple&logoColor=white)](https://apple.com)
[![Architecture](https://img.shields.io/badge/Architecture-Apple%20Silicon%20%7C%20Intel-5856D6.svg?style=flat)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-FA7343.svg?style=flat&logo=swift&logoColor=white)](https://swift.org)
[![UI](https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-00D9F2.svg?style=flat)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat)](LICENSE)

---

## 🌌 Overview

Modern development workflows—running local LLMs with **Ollama** or **vLLM**, executing recursive agent tasks with **Claude Code**, compiling multi-crate **Rust** workspaces, or building massive **Docker** images—often run for hours. However, closing your MacBook lid or leaving it unattended triggers macOS sleep, halting background processes, severing SSH tunnels, and aborting tasks.

**Nightowler** is a native, ultra-lightweight macOS menu-bar companion and CLI daemon that intelligently keeps your Mac awake and protects hardware health. It pairs a **Double Shot**-inspired frosted obsidian interface with low-level **IOKit** power assertions, direct **AppleSMC** hardware fan controls, and an autonomous workload detection engine.

```
┌─────────────────────────────────────────────────────────────────┐
│  👁️  Nightowler                          NOCTURNAL GUARDIAN  ●  │
│      Overview  ·  Auto  ·  Safety  ·  Cooling  ·  Rules  ·  Log │
├─────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  ◉  CLAMSHELL LOCK ACTIVE                                 │  │
│  │     Autonomous Guardian: claude & docker executing        │  │
│  │     Auto-releases when jobs finish or on 20% battery floor│  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  [ Keep Awake             ]  [ Clamshell Guard        ]  [ Auto ]│
│  System sleep disabled       Running with lid shut       Active │
│                                                                 │
│  QUICK SESSION TIMER                                            │
│  [ Off ]   [ 30m ]   [ 1h ]   [ 2h ]   [ 4h ]   [ 8h ]          │
│                                                                 │
│  LIVE HARDWARE TELEMETRY                                        │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐     │
│  │  BATTERY     │     │  CPU DIE     │     │  TACHOMETER  │     │
│  │  96% AC      │     │  48°C Normal │     │  2450 RPM    │     │
│  └──────────────┘     └──────────────┘     └──────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

---

## ✨ Key Capabilities

### 🌙 Guarded Clamshell Mode
- Keeps your Mac fully operational with the laptop display shut.
- Manages power subsystem states safely via native `pmset` integration.
- Automatically restores standard macOS sleep behavior upon clean exit or safety cutoff.

### ⚡ Autonomous Workload Watcher
- Continuously scans for active developer tooling, background compilers, and AI agent processes:
  - **AI Agents & Tools:** `claude`, `cursor`, `codex`, `ollama`, `lmstudio`, `vllm`, `whisper`
  - **Containers & Runtimes:** `docker`, `dockerd`, `python`, `node`, `bun`
  - **Build Systems:** `xcodebuild`, `cargo`, `rustc`, `go`, `vite`, `ffmpeg`
- Holds system assertions only while workloads are active, with configurable idle grace timeouts.

### ❄️ AppleSMC Thermal & Fan Control
- Direct IOKit kernel communication with the `AppleSMC` hardware driver (`kSMCUserClientOpen`, `FS! `, `F0Tg`/`F1Tg`).
- 5 tailored acoustic and cooling profiles:
  - **Automatic Dynamic:** Lets system firmware regulate RPM dynamically.
  - **Nocturnal Boost (~70% RPM):** Proactive cooling during long multi-hour background jobs.
  - **High Performance (~85% RPM):** For heavy local LLM inference or Docker builds.
  - **Maximum Dissipation (100% RPM):** Maximum airflow when running intensive jobs in clamshell mode.
  - **Quiet Baseline:** Minimum acoustic profile for silent night runs.

### 🛡️ Multi-Sensor Safety Governor
Unattended background execution requires uncompromising hardware protection:
- **Low-Battery Auto-Release:** Automatically releases wake-locks if battery drops below a user-selected threshold (default: 20%).
- **Critical Battery Sleep:** Forces macOS sleep immediately if battery reaches `<= 5%` to prevent sudden shutdowns and battery wear.
- **AC Charging-Only Mode:** Disengages keep-awake if the power adapter is disconnected (prevents waking up in a laptop bag).
- **Thermal Emergency Cutoff:** Automatically stops wake-locks and maxes fans if CPU temperatures reach 95°C.

### 📡 Remote Alerts & Webhooks
- Instant push notifications when long-running tasks terminate or safety thresholds trigger.
- Native integration with **Telegram Bot API**, **Discord Webhooks**, **Slack Incoming Webhooks**, and arbitrary **JSON HTTP Endpoints**.

### 🦉 Minimalist Vector Owl Menu Bar Companion
- **Adaptive Vector Rendering**: Clean, high-contrast monochrome owl silhouette rendered programmatically via `CGContext` vector geometry.
- **Dynamic State Feedback**:
  - **Awake & Vigilant (Wide Open Eyes)**: Signals active wake locks, background workloads, or timer sessions.
  - **Nocturnal Rest (Sleepy Closed Eyes)**: Indicates the Mac is sleeping normally with zero wake locks.
  - **Clamshell Crown Badge**: Displays a subtle forehead indicator when running with the MacBook display closed.
- **Native Menu Bar Appearance**: Configured with `isTemplate = true` to seamlessly match macOS light/dark menu bar modes and ProMotion Liquid Retina displays.

---

## 🏗️ Architecture & Internals

Nightowler is organized into decoupled Swift packages:

```
Sources/
├── NightowlerCore/                 # Core engine & low-level hardware links
│   ├── Power/                      # IOKit PowerAssertionManager, ClamshellManager, HelperClient
│   ├── Hardware/                   # AppleSMC Controller, BatteryMonitor, ThermalMonitor
│   ├── Automation/                 # ProcessWatcher, RuleEngine, RulesStore, RuleModels
│   ├── Safety/                     # SafetyGovernor (multi-sensor cutoff), ActivityLog
│   ├── Alerts/                     # WebhookManager (Telegram, Discord, Slack, HTTP)
│   ├── State/                      # AppState, AppSettings, EngineCapabilities
│   └── IPC/                        # Unix Domain Socket Server & Client (/tmp/nightowler.sock)
│
├── NightowlerApp/                  # Native SwiftUI Menu Bar Application
│   ├── AppDelegate.swift           # Accessory life-cycle & system hooks
│   ├── MenuBar/                    # Status item controller & floating NSPanel
│   └── Views/                      # Frosted glass obsidian UI (Double Shot aesthetic)
│
├── NightowlerCLI/                  # Standalone terminal utility
│   └── main.swift                  # Dual-mode command wrapper & daemon client
│
├── NightowlerHelper/               # Privileged helper daemon for passwordless pmset
│   └── main.swift                  # NSXPCListener service
│
└── NightowlerTestRunner/           # Automated verification test suite
    └── main.swift                  # End-to-end integration tests
```

### Low-Level Subsystem Mechanics

1. **Power Assertions (`IOKit.pwr_mgt`):**
   Utilizes `IOPMAssertionCreateWithName` with `kIOPMAssertionTypePreventUserIdleSystemSleep` and optional `kIOPMAssertionTypePreventUserIdleDisplaySleep` to inform the macOS power kernel that background processing is active.
2. **Clamshell Lock (`pmset`):**
   Toggles system sleep via privileged helper or direct execution (`/usr/bin/pmset -a disablesleep 1`), with automated recovery handlers registered via `atexit` and `NSApplicationDelegate.applicationWillTerminate`.
3. **AppleSMC Protocol:**
   Talks directly to `AppleSMC` IOKit service keys:
   - `FS! `: Manual fan mode bitmask.
   - `F0Tg` / `F1Tg`: Target fan RPM encoded in `fpe2` format.
   - `F0Ac` / `F1Ac`: Real-time tachometer readings.
   - `TC0P`, `TC0D`, `Tp0P`: CPU die core thermistors decoded via `sp78`.
4. **Unix Domain Socket IPC:**
   Exposes a thread-safe JSON-RPC socket at `/tmp/nightowler.sock` with `0600` user permissions.

---

## 🚀 Quick Start

### 1. Clone & Build

```bash
# Clone repository
git clone https://github.com/ayonm95/nightowler.git
cd nightowler

# Package release binaries and install CLI to ~/.local/bin
./Scripts/package_app.sh
```

### 2. Configure Permissions (Optional for Passwordless Clamshell)

To allow Nightowler to toggle closed-lid sleep prevention seamlessly without interactive admin password prompts:

```bash
nightowler setup
```
*(Writes `/etc/sudoers.d/nightowler` allowing passwordless `/usr/bin/pmset -a disablesleep 1/0`)*

### 3. Launch the Menu Bar App

```bash
open /Applications/Nightowler.app
# or
open dist/Nightowler.app
```

The Nightowler owl eye icon appears in your menu bar. Click to inspect live telemetry, change cooling profiles, configure rules, or manage watched processes. Right-click the menu icon for an instant wake toggle.

---

## ⌨️ CLI Usage Guide

The `nightowler` CLI operates in two modes:

### Mode 1: Transparent Command Wrapper (`nightowler -- <command>`)
Wraps any long-running command. Nightowler automatically acquires an IOKit power assertion, runs your command forwarding all `stdin`, `stdout`, and `stderr`, and safely releases the assertion once the command terminates.

```bash
# Keep Mac awake for a long Python AI training loop
nightowler -- python train.py --epochs 100 --batch-size 32

# Keep Mac awake during a large Docker build
nightowler -- docker compose up --build

# Run a heavy Xcode build without interruption
nightowler -- xcodebuild -workspace App.xcworkspace -scheme Release build
```

### Mode 2: Daemon Remote Control
Interacts directly with the running menu-bar app via IPC:

```bash
# Check full system telemetry (human-readable or JSON)
nightowler status
nightowler status --json

# Start or stop manual keep-awake session
nightowler start          # Keep awake indefinitely
nightowler start 7200     # Keep awake for 2 hours (7200s)
nightowler stop           # Stop keep-awake

# Toggle Clamshell Guard (closed-lid mode)
nightowler clamshell on
nightowler clamshell off

# Autonomous Workload Watcher
nightowler autowatch on
nightowler autowatch off

# Manage watched processes
nightowler watch jupyter vllm blender whisper
nightowler patterns
nightowler unwatch blender

# AppleSMC Hardware Fan Controls
nightowler fan auto       # System dynamic curve
nightowler fan boost      # 70% fan speed
nightowler fan high       # 85% fan speed
nightowler fan max        # 100% maximum dissipation

# One-Time Permission Setup (Passwordless Clamshell)
nightowler setup

# Dispatch remote test alerts
nightowler notify "Training Complete" "Loss converged to 0.0124 after 100 epochs."

# Safe Sleep Request
nightowler sleep          # Refuses if watched tasks are currently running
nightowler sleep --force  # Forces immediate sleep
```

---

## 🧪 Testing & Verification

Nightowler includes an automated verification test suite covering power assertion allocation, process discovery, rule engine evaluation, activity logging, IPC serialization, and AppleSMC communication:

```bash
swift run NightowlerTestRunner
```

Sample output:
```
=== Running Nightowler Verification Suite ===

[1] Testing Native Engine Capabilities
  ✅ PASS: Hardware fan control capability active
  ✅ PASS: Autonomous workload watcher active
  ✅ PASS: Guarded clamshell execution active
  ✅ PASS: Reactive rules engine active
  ✅ PASS: Multi-channel webhook dispatch active
  ✅ PASS: In-memory audit logging active
  ✅ PASS: Continuous session mode active

[2] Testing Power Assertion Manager
  ✅ PASS: Initially holds no system assertion
  ✅ PASS: Successfully created system power assertion
  ✅ PASS: holdsSystemAssertion is true
  ✅ PASS: Successfully released system power assertion

[3] Testing Rules Store
  ✅ PASS: Rules list is populated
  ✅ PASS: Contains Claude Code rule
  ✅ PASS: Contains Cursor rule
  ✅ PASS: Contains Docker rule
  ✅ PASS: Contains Battery sleep rule

[4] Testing Rule Engine Evaluation
  ✅ PASS: Rule builtin.battery-sleep-5 triggered at 4% battery

[5] Testing AppState Rule Action Handler
  ✅ PASS: Rule action .startKeepAwake sets AppState mode to .on
  ✅ PASS: Rule action .setCoolingPreset('boost') sets coolingMode to .boost

[6] Testing Process Watcher
  ✅ PASS: Default patterns contain 'claude'
  ✅ PASS: Default patterns contain 'cursor'
  ✅ PASS: Default patterns contain 'python'
  ✅ PASS: Added 'testtoolxyz'
  ✅ PASS: Removed 'testtoolxyz'

[7] Testing Activity Log
  ✅ PASS: Log cleared successfully
  ✅ PASS: Logged 1 event
  ✅ PASS: Event kind matches
  ✅ PASS: Event value matches

[8] Testing IPC Serialization
  ✅ PASS: IPCRequest serialized and deserialized correctly
  ✅ PASS: IPCResponse serialized and deserialized correctly

[9] Testing Webhook Configuration Serialization
  ✅ PASS: WebhookConfig roundtrip successful

[10] Testing SMC & Hardware
  ℹ️ SMC Available: true, Fan Count: 0, CPU Temp: 0.0°C
  ✅ PASS: Hardware query completed without crashes

[11] Testing Clamshell Manager & Kernel Sleep State
  ✅ PASS: Kernel SleepDisabled is verified as 1
  ✅ PASS: Kernel SleepDisabled restored to 0

🎉 ALL TESTS PASSED! Nightowler verification 100% complete.
```

---

## 🔒 Security & Privacy

- **100% Local & Offline:** Nightowler runs entirely locally on your Mac. No tracking, telemetry, or cloud dependencies.
- **IPC Isolation:** Sockets are strictly locked to `0600` permissions belonging to your user account.
- **Fail-Safe Restoration:** System power settings and clamshell locks are automatically restored to macOS defaults on app quit, system shutdown, or critical safety triggers.

---

## 📄 License

Nightowler is open-source software released under the **[MIT License](LICENSE)**.  
Copyright © 2026 **Ayon Moitra**. Engineered natively for developers, researchers, and the nocturnal AI community.
