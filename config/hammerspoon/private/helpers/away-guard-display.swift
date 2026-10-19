// Session-only display control. Private symbols are checked at runtime.
import Foundation
import CoreGraphics
import Darwin

struct Failure: Error { let message: String }
// Independent of Hammerspoon's Lua loop and of display/logging work on the main thread.
final class GuardWatchdog {
    private let mutex = NSLock()
    private var lastHeartbeat = ProcessInfo.processInfo.systemUptime
    private var heartbeatTimeout: TimeInterval = 2
    private var monitoring = false
    private var enabled = false
    private var incident = false
    private var incidentReason: String?
    private var incidentReported = false
    private var lockObserved = false
    private var disarmed = false
    let lockScreen: () -> Void
    let isLocked: () -> Bool
    let reportIncident: (String) -> Void
    init(lockScreen: @escaping () -> Void, isLocked: @escaping () -> Bool,
         reportIncident: @escaping (String) -> Void = { _ in }) {
        self.lockScreen = lockScreen; self.isLocked = isLocked
        self.reportIncident = reportIncident
    }
    func enable(now: TimeInterval = ProcessInfo.processInfo.systemUptime, timeout: TimeInterval = 2) {
        mutex.lock(); defer { mutex.unlock() }
        enabled = true; lastHeartbeat = now; heartbeatTimeout = timeout
    }
    func beginMonitoring(now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        mutex.lock(); defer { mutex.unlock() }
        guard enabled && !incident && !disarmed else { return false }
        monitoring = true; heartbeatTimeout = 2; lastHeartbeat = now
        return true
    }
    var isMonitoring: Bool {
        mutex.lock(); defer { mutex.unlock() }
        return monitoring
    }
    func heartbeat(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        mutex.lock(); defer { mutex.unlock() }
        lastHeartbeat = now
    }
    func disarm() { mutex.lock(); disarmed = true; mutex.unlock() }
    func trip(_ reason: String = "display monitor incident") {
        mutex.lock()
        if !incident { incident = true; incidentReason = reason }
        mutex.unlock()
        check()
    }
    func check(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        mutex.lock(); defer { mutex.unlock() }
        guard enabled && !disarmed else { return }
        if now - lastHeartbeat > heartbeatTimeout && !incident {
            incident = true
            incidentReason = monitoring ? "parent heartbeat timed out while armed" : "parent heartbeat timed out during display setup"
        }
        guard incident && !lockObserved else { return }
        if isLocked() { lockObserved = true; return }
        lockScreen() // Request the lock before any fallible diagnostics.
        if !incidentReported {
            incidentReported = true
            reportIncident(incidentReason ?? "display monitor incident")
        }
    }
}
var watchdog: GuardWatchdog?
var watchdogTimer: DispatchSourceTimer?
func consumeCommands(_ fd: Int32, _ guardWatchdog: GuardWatchdog, arm: (() -> Void)? = nil, disarm: () -> Void) {
    var buffer = "", byte: UInt8 = 0
    while true {
        let count = read(fd, &byte, 1)
        if count == -1 && errno == EINTR { continue }
        guard count == 1 else { guardWatchdog.trip("parent input pipe closed"); return }
        if byte == 10 {
            if buffer == "heartbeat" { guardWatchdog.heartbeat() }
            else if buffer == "arm", let arm { arm() }
            else if buffer == "disarm" { guardWatchdog.disarm(); disarm(); return }
            else { guardWatchdog.trip() }
            buffer = ""
        } else if buffer.count < 64 { buffer.append(Character(UnicodeScalar(byte))) }
        else { guardWatchdog.trip() }
    }
}
func lockFunction() throws -> @convention(c) () -> Void {
    // Same login.framework entry point used by hs.caffeinate.lockScreen().
    guard let framework = dlopen("/System/Library/PrivateFrameworks/login.framework/login", RTLD_NOW),
          let pointer = dlsym(framework, "SACLockScreenImmediate") else {
        throw Failure(message: "Independent lock API unavailable")
    }
    return unsafeBitCast(pointer, to: (@convention(c) () -> Void).self)
}
func screenIsLocked() -> Bool {
    (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool == true
}
func brightness(_ id: UInt32) throws -> Float {
    typealias Get = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    guard let brightnessFramework,
          let pointer = dlsym(brightnessFramework, "DisplayServicesGetBrightness") else {
        throw Failure(message: "Native brightness API unavailable")
    }
    var value: Float = 0
    guard unsafeBitCast(pointer, to: Get.self)(id, &value) == 0, value.isFinite else {
        throw Failure(message: "Cannot read native brightness")
    }
    return value
}
func emit(_ event: String, _ fields: [String: Any] = [:]) {
    var value = fields; value["event"] = event
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) {
        let line = data + Data([10])
        // Diagnostics cannot block locking or crash on a disconnected parent.
        line.withUnsafeBytes { bytes in _ = write(STDOUT_FILENO, bytes.baseAddress, bytes.count) }
    }
}
let framework = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
func symbol<T>(_ name: String, _: T.Type) throws -> T {
    guard let framework, let pointer = dlsym(framework, name) else {
        throw Failure(message: "Missing private API: \(name)")
    }
    return unsafeBitCast(pointer, to: T.self)
}
// Same DisplayServices SPI used by Lunar; resolve dynamically for OS compatibility.
let brightnessFramework = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
func autoBrightness(_ id: UInt32, set value: Bool? = nil) throws -> Bool {
    typealias Get = @convention(c) (UInt32, UnsafeMutablePointer<Bool>) -> Int32
    typealias Set = @convention(c) (UInt32, Bool) -> Int32
    guard let brightnessFramework,
          let getPointer = dlsym(brightnessFramework, "DisplayServicesAmbientLightCompensationEnabled"),
          let setPointer = dlsym(brightnessFramework, "DisplayServicesEnableAmbientLightCompensation") else {
        throw Failure(message: "Auto-brightness API unavailable")
    }
    let get = unsafeBitCast(getPointer, to: Get.self)
    let set = unsafeBitCast(setPointer, to: Set.self)
    if let value, set(id, value) != 0 { throw Failure(message: "Cannot set auto-brightness") }
    var enabled = false
    guard get(id, &enabled) == 0 else { throw Failure(message: "Cannot read auto-brightness") }
    if let value, enabled != value { throw Failure(message: "Auto-brightness verification failed") }
    return enabled
}
func internalDisplay() throws -> UInt32 {
    guard let id = try displays().first(where: { CGDisplayIsBuiltin($0) != 0 }) else {
        throw Failure(message: "Internal display unavailable")
    }
    return id
}
typealias List = @convention(c) (UInt32, UnsafeMutablePointer<UInt32>?, UnsafeMutablePointer<UInt32>?) -> Int32
typealias Enable = @convention(c) (CGDisplayConfigRef?, UInt32, Bool) -> Int32
func displays() throws -> [UInt32] {
    let list = try symbol("CGSGetDisplayList", List.self)
    var ids = [UInt32](repeating: 0, count: 128), count: UInt32 = 0
    guard list(128, &ids, &count) == 0, count < 128 else { throw Failure(message: "Display enumeration failed") }
    return ids.prefix(Int(count)).filter {
        CGDisplayIsOnline($0) != 0 || CGDisplayVendorNumber($0) != 0 || CGDisplayModelNumber($0) != 0 || CGDisplaySerialNumber($0) != 0
    }
}
func uuid(_ id: UInt32) throws -> String {
    typealias CreateUUID = @convention(c) (UInt32) -> Unmanaged<CFUUID>?
    let create = try symbol("CGDisplayCreateUUIDFromDisplayID", CreateUUID.self)
    guard let value = create(id)?.takeRetainedValue() else { throw Failure(message: "No display UUID") }
    return CFUUIDCreateString(nil, value) as String
}
func identity(_ id: UInt32) -> String {
    "\(id):\(CGDisplayVendorNumber(id)):\(CGDisplayModelNumber(id)):\(CGDisplaySerialNumber(id))"
}
func topology() throws -> [String] { try displays().map { identity($0) }.sorted() }
func resolve(_ wanted: String, _ ids: [UInt32]) throws -> UInt32? {
    if let exact = ids.first(where: { identity($0) == wanted }) { return exact }
    let hardware = wanted.split(separator: ":").dropFirst().joined(separator: ":")
    let matches = ids.filter { identity($0).split(separator: ":").dropFirst().joined(separator: ":") == hardware }
    if matches.count > 1 { throw Failure(message: "Ambiguous display identity: \(wanted)") }
    return matches.first
}
func online() throws -> [UInt32] {
    var ids = [UInt32](repeating: 0, count: 128), count: UInt32 = 0
    guard CGGetOnlineDisplayList(128, &ids, &count) == .success, count < 128 else {
        throw Failure(message: "Online display enumeration failed")
    }
    return ids.prefix(Int(count)).sorted()
}
func configure(_ ids: [UInt32], enabled: Bool) throws {
    if ids.isEmpty { return }
    let enable = try symbol("SLSConfigureDisplayEnabled", Enable.self)
    var config: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&config) == .success, let config else { throw Failure(message: "Begin configuration failed") }
    var committed = false
    defer { if !committed { CGCancelDisplayConfiguration(config) } }
    for id in ids {
        if !enabled && CGDisplayIsInMirrorSet(id) != 0 {
            guard CGConfigureDisplayMirrorOfDisplay(config, id, kCGNullDirectDisplay) == .success else { throw Failure(message: "Unmirror failed") }
        }
        guard enable(config, id, enabled) == 0 else { throw Failure(message: "Configure display \(id) failed") }
    }
    committed = true // Complete consumes the transaction, including on failure.
    let result = CGCompleteDisplayConfiguration(config, .forSession)
    guard result == .success else { throw Failure(message: "Commit failed: \(result.rawValue)") }
}
func restore(_ wanted: [String]) throws {
    // Resolve saved hardware identities against the current private list; disabled displays are absent from the public list.
    for _ in 0..<15 {
        let current = try displays()
        let ids = try wanted.compactMap { try resolve($0, current) }.filter { CGDisplayIsBuiltin($0) == 0 }
        let active = try online()
        let missing = ids.filter { !active.contains($0) }
        if missing.isEmpty { return } // physically unplugged screens need no enabling
        // WindowServer can report a failed commit while a display is coming online.
        // Re-enumerate and verify on the next attempt rather than losing the recovery snapshot.
        do { try configure(missing, enabled: true) } catch {
            FileHandle.standardError.write(Data("Restore retry: \(error)\n".utf8))
        }
        Thread.sleep(forTimeInterval: 0.3)
    }
    throw Failure(message: "External displays did not return online")
}
var armed = false
let callback: CGDisplayReconfigurationCallBack = { id, flags, _ in
    if armed && !flags.contains(.beginConfigurationFlag) {
        watchdog?.trip("display reconfiguration")
        emit("changed", ["reason": "display reconfiguration", "displayID": id, "flags": flags.rawValue])
    }
}
do {
    let args = Array(CommandLine.arguments.dropFirst())
    switch args.first {
    case "self-test":
        var locks = 0, locked = false
        let test = GuardWatchdog(lockScreen: { locks += 1 }, isLocked: { locked })
        test.enable(now: 10); test.check(now: 11); precondition(locks == 0)
        test.heartbeat(now: 11); test.check(now: 12.9); precondition(locks == 0)
        test.check(now: 13.1); precondition(locks == 1)
        test.check(now: 13.4); precondition(locks == 2)
        locked = true; test.check(now: 13.7); locked = false
        test.check(now: 14); precondition(locks == 2) // Allow authenticated return.
        let disarmed = GuardWatchdog(lockScreen: { locks += 1 }, isLocked: { false })
        disarmed.enable(now: 10); disarmed.disarm(); disarmed.check(now: 100); disarmed.trip()
        precondition(locks == 2)
        let disconnected = GuardWatchdog(lockScreen: { locks += 1 }, isLocked: { false })
        disconnected.enable(); disconnected.trip(); precondition(locks == 3)
        var descriptors: [Int32] = [0, 0]
        precondition(pipe(&descriptors) == 0)
        let commands = GuardWatchdog(lockScreen: { locks += 1 }, isLocked: { false })
        commands.enable(); var didDisarm = false
        let input = Array("heartbeat\ndisarm\n".utf8)
        _ = input.withUnsafeBytes { write(descriptors[1], $0.baseAddress, $0.count) }
        close(descriptors[1]);consumeCommands(descriptors[0], commands, disarm: { didDisarm = true });close(descriptors[0])
        commands.trip();precondition(didDisarm && locks == 3)
        precondition(pipe(&descriptors) == 0)
        close(descriptors[1]);consumeCommands(descriptors[0], disconnected, disarm: {});close(descriptors[0])
        precondition(locks == 4)
        // The main thread can block while the independent timer still requests a lock.
        let signalled = DispatchSemaphore(value: 0)
        let asynchronous = GuardWatchdog(lockScreen: { signalled.signal() }, isLocked: { false })
        asynchronous.enable(now: ProcessInfo.processInfo.systemUptime - 3)
        let independent = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "away-guard.test"))
        independent.schedule(deadline: .now(), repeating: .milliseconds(100))
        independent.setEventHandler { asynchronous.check() };independent.resume()
        precondition(signalled.wait(timeout: .now() + 1) == .success)
        asynchronous.disarm();independent.cancel()
        // Reconfiguration can outlast the armed heartbeat budget. Preparation
        // is bounded separately, and only a successful darkening handshake
        // switches the independent watchdog to its strict two-second budget.
        var handshakeLocks = 0, reasons: [String] = []
        let setup = GuardWatchdog(lockScreen: { handshakeLocks += 1 }, isLocked: { false },
            reportIncident: { reasons.append($0) })
        setup.enable(now: 10, timeout: 25)
        setup.check(now: 13); precondition(handshakeLocks == 0 && !setup.isMonitoring)
        precondition(setup.beginMonitoring(now: 15) && setup.isMonitoring)
        setup.check(now: 16.9); precondition(handshakeLocks == 0)
        setup.check(now: 17.1); precondition(handshakeLocks == 1)
        precondition(reasons.last == "parent heartbeat timed out while armed")
        precondition(!setup.beginMonitoring(now: 18)) // An incident cannot be reset by a late ACK.
        let stalledSetup = GuardWatchdog(lockScreen: { handshakeLocks += 1 }, isLocked: { false },
            reportIncident: { reasons.append($0) })
        stalledSetup.enable(now: 10, timeout: 25)
        stalledSetup.check(now: 35.1); precondition(handshakeLocks == 2)
        precondition(reasons.last == "parent heartbeat timed out during display setup")
        let failedSetup = GuardWatchdog(lockScreen: { handshakeLocks += 1 }, isLocked: { false })
        failedSetup.enable(timeout: 25);failedSetup.trip("topology changed during setup")
        precondition(handshakeLocks == 3) // Physical failures still lock immediately.
        precondition(pipe(&descriptors) == 0)
        let handshakeInput = Array("arm\ndisarm\n".utf8)
        _ = handshakeInput.withUnsafeBytes { write(descriptors[1], $0.baseAddress, $0.count) }
        close(descriptors[1])
        var acknowledged = false
        let acknowledgedSetup = GuardWatchdog(lockScreen: { handshakeLocks += 1 }, isLocked: { false })
        acknowledgedSetup.enable(timeout: 25)
        consumeCommands(descriptors[0], acknowledgedSetup,
            arm: { acknowledged = acknowledgedSetup.beginMonitoring() }, disarm: {})
        close(descriptors[0]);precondition(acknowledged && handshakeLocks == 3)
        let externalLock = GuardWatchdog(lockScreen: { preconditionFailure("already locked") },
            isLocked: { true }, reportIncident: { _ in preconditionFailure("must not blame helper for an external lock") })
        externalLock.enable();externalLock.trip("brightness rose after external lock")
        _ = try lockFunction() // Resolve, never invoke, the actual API.
        emit("self_test_passed", ["cases": "heartbeat timeout, retries, lock observation, disarm, pipe commands/EOF, independent queue, bounded setup/arming handshake, incident diagnostics, lock API resolution"])
    case "status":
        _ = try lockFunction()
        emit("status", ["topology": try topology(), "online": try online(), "autoBrightness": try autoBrightness(internalDisplay()),
                        "brightness": try brightness(internalDisplay()), "lockAPIAvailable": true])
    case "restore":
        let identities = args.dropFirst().filter { !$0.hasPrefix("--auto-brightness=") }
        try restore(Array(identities))
        if let setting = args.first(where: { $0.hasPrefix("--auto-brightness=") }) {
            _ = try autoBrightness(internalDisplay(), set: setting == "--auto-brightness=on")
        }
        emit("restored")
    case "watch":
        let handshake = args.contains("--arm-handshake")
        let lock = try lockFunction()
        let guardWatchdog = GuardWatchdog(lockScreen: { lock() }, isLocked: screenIsLocked,
            reportIncident: { emit("watchdog_lock", ["reason": $0]) })
        watchdog = guardWatchdog
        signal(SIGPIPE, SIG_IGN) // A closed stdout must not kill the independent watchdog.
        guard fcntl(STDOUT_FILENO, F_SETFL, fcntl(STDOUT_FILENO, F_GETFL) | O_NONBLOCK) != -1 else {
            throw Failure(message: "Cannot configure nonblocking monitor output")
        }
        let ids = try displays()
        guard let internalID = ids.first(where: { CGDisplayIsBuiltin($0) != 0 && CGDisplayIsOnline($0) != 0 }) else {
            throw Failure(message: "Open the MacBook lid first")
        }
        let baseline = try topology()
        let external = ids.filter { CGDisplayIsBuiltin($0) == 0 && CGDisplayIsOnline($0) != 0 }
        let saved = external.map { identity($0) }
        _ = try symbol("SLSConfigureDisplayEnabled", Enable.self)
        let automatic = try autoBrightness(internalID)
        _ = try brightness(internalID) // Fail before disabling displays if native monitoring is unavailable.
        emit("snapshot", ["external": saved, "internal": try uuid(internalID), "autoBrightness": automatic])
        // Hammerspoon must persist the snapshot before allowing any display changes.
        // Read exactly one line without stdio read-ahead; the background reader owns subsequent input.
        var command = "", byte: UInt8 = 0
        while read(STDIN_FILENO, &byte, 1) == 1 && byte != 10 { command.append(Character(UnicodeScalar(byte))) }
        guard command == "disable" else { throw Failure(message: "No disable authorization") }
        // Display reconfiguration can briefly block the parent's Lua thread.
        // Preparation has the same bounded 25s budget as the parent; explicit
        // topology failures/EOF still trip immediately. Tighten to 2s only after
        // the parent confirms zero brightness and the native reader verifies it.
        guardWatchdog.enable(timeout: handshake ? 25 : 2)
        if !handshake { _ = guardWatchdog.beginMonitoring() }
        let queue = DispatchQueue(label: "away-guard.watchdog")
        let independentTimer = DispatchSource.makeTimerSource(queue: queue)
        watchdogTimer = independentTimer // Retain through setup errors and parent disconnects.
        independentTimer.schedule(deadline: .now(), repeating: .milliseconds(300))
        independentTimer.setEventHandler { guardWatchdog.check() }
        independentTimer.resume()
        DispatchQueue(label: "away-guard.commands").async {
            consumeCommands(STDIN_FILENO, guardWatchdog, arm: {
                do {
                    guard try brightness(internalID) == 0 else {
                        throw Failure(message: "Cannot arm before internal brightness reaches zero")
                    }
                    guard guardWatchdog.beginMonitoring() else { return }
                    emit("armed")
                } catch {
                    guardWatchdog.trip("arming handshake failed")
                    emit("error", ["reason": String(describing: error)])
                }
            }, disarm: { exit(0) })
        }
        guard try topology() == baseline else { throw Failure(message: "Topology changed before disabling") }
        _ = try autoBrightness(internalID, set: false)
        emit("auto_brightness_disabled", ["previous": automatic])
        do { try configure(external, enabled: false) } catch {
            emit("progress", ["online": try online(), "reason": "Initial disable needs verification: \(error)"])
        }
        let deadline = Date().addingTimeInterval(15)
        var stable = 0
        var lastOnline: [UInt32]?
        var lastDisable = Date()
        while stable < 5 {
            guard try topology() == baseline else { throw Failure(message: "Physical topology changed during setup") }
            let currentOnline = try online()
            if currentOnline != lastOnline { emit("progress", ["online": currentOnline]); lastOnline = currentOnline }
            if currentOnline == [internalID] {
                stable += 1
            } else {
                stable = 0
                guard currentOnline.contains(internalID) else { throw Failure(message: "Internal display went offline") }
                // Space/fullscreen migrations can partially apply or undo the first
                // transaction. Converge only during setup and only for saved targets.
                if Date().timeIntervalSince(lastDisable) >= 0.6 {
                    for id in external where currentOnline.contains(id) {
                        do { try configure([id], enabled: false) } catch {
                            emit("progress", ["online": currentOnline, "reason": "Retry disabling \(id): \(error)"])
                        }
                    }
                    lastDisable = Date()
                }
            }
            guard Date() < deadline else { throw Failure(message: "External displays stayed online: \(currentOnline)") }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        guard CGDisplayRegisterReconfigurationCallback(callback, nil) == .success else { throw Failure(message: "Cannot watch display changes") }
        armed = true
        emit("ready")
        let timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            do {
                if try topology() != baseline || online() != [internalID] {
                    guardWatchdog.trip()
                    emit("changed", ["reason": "physical or online topology changed", "online": try online(), "topology": try topology()])
                }
                let value = try brightness(internalID)
                if guardWatchdog.isMonitoring && value > 0 {
                    guardWatchdog.trip("brightness increased or unreadable: \(value)")
                    emit("changed", ["reason": "brightness increased or unreadable: \(value)"])
                }
                emit("heartbeat")
            } catch {
                guardWatchdog.trip()
                emit("error", ["reason": String(describing: error)])
            }
        }
        RunLoop.current.add(timer, forMode: .common)
        RunLoop.current.run()
    default: throw Failure(message: "Usage: away-guard-display status|watch|restore [IDENTITY ...]")
    }
} catch {
    watchdog?.trip()
    emit("error", ["reason": (error as? Failure)?.message ?? String(describing: error)])
    if watchdogTimer != nil { RunLoop.current.run() } // Keep retrying independently after setup failure.
    exit(1)
}
