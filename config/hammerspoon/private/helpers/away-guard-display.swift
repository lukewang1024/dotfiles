// Session-only display control. Private symbols are checked at runtime.
import Foundation
import CoreGraphics
import Darwin

struct Failure: Error { let message: String }
// Both processes use mach_absolute_time (hs.timer.absoluteTime is nanoseconds).
// Wall-clock changes must not renew a transport or monitoring deadline.
let clockScale: Double = {
    var info = mach_timebase_info_data_t()
    mach_timebase_info(&info)
    return Double(info.numer) / Double(info.denom) / 1_000_000_000
}()
func monotonicNow() -> TimeInterval { Double(mach_absolute_time()) * clockScale }
enum GuardTiming {
    static let parentHeartbeatTimeout: TimeInterval = 10
    static let nativeCheckTimeout: TimeInterval = 2
    static let pollInterval: TimeInterval = 0.3
}
struct GapStatistics {
    var maximum: TimeInterval = 0
    var buckets = [0, 0, 0, 0]
    mutating func record(_ gap: TimeInterval) {
        maximum = max(maximum, gap)
        buckets[gap <= 0.5 ? 0 : gap <= 2 ? 1 : gap <= 10 ? 2 : 3] += 1
    }
    var value: [String: Any] { ["maximumSeconds": maximum, "bucketsLeHalfLeTwoLeTenOverTen": buckets] }
}
// Independent of the parent Lua loop AND actual display checks on the main loop.
final class GuardWatchdog {
    private let mutex = NSLock()
    private var lastHeartbeat = monotonicNow()
    private var lastParentReceived = monotonicNow()
    private var parentSequence: UInt64 = 0
    private var heartbeatTimeout = GuardTiming.parentHeartbeatTimeout
    private var lastNativeCheck = monotonicNow()
    private var nativeSequence: UInt64 = 0
    private var parentGaps = GapStatistics(), nativeGaps = GapStatistics()
    private var monitoring = false
    private var enabled = false
    private var incidentReason: String?
    private let incidentId = UUID().uuidString
    private var requestedAt: TimeInterval?
    private var incidentReported = false
    private var lockObserved = false
    private var disarmed = false
    let lockScreen: () -> Void
    let isLocked: () -> Bool
    let reportIncident: ([String: Any]) -> Void
    init(lockScreen: @escaping () -> Void, isLocked: @escaping () -> Bool,
         reportIncident: @escaping ([String: Any]) -> Void = { _ in }) {
        self.lockScreen = lockScreen; self.isLocked = isLocked
        self.reportIncident = reportIncident
    }
    func enable(now: TimeInterval = monotonicNow(), timeout: TimeInterval = GuardTiming.parentHeartbeatTimeout) {
        mutex.lock(); defer { mutex.unlock() }
        enabled = true; lastHeartbeat = now; lastParentReceived = now; heartbeatTimeout = timeout
    }
    func beginMonitoring(now: TimeInterval = monotonicNow()) -> Bool {
        mutex.lock(); defer { mutex.unlock() }
        expireLocked(now: now)
        guard enabled && !monitoring && incidentReason == nil && !disarmed else { return false }
        monitoring = true; heartbeatTimeout = GuardTiming.parentHeartbeatTimeout
        lastHeartbeat = now; lastParentReceived = now; lastNativeCheck = now
        return true
    }
    var isMonitoring: Bool {
        mutex.lock(); defer { mutex.unlock() }
        return monitoring
    }
    private func healthLocked(now: TimeInterval) -> [String: Any] {
        ["parentSequence": parentSequence, "nativeSequence": nativeSequence,
         "lastParentSentUptime": lastHeartbeat, "lastNativeCheckUptime": lastNativeCheck,
         "parentHeartbeatAgeSeconds": now-lastHeartbeat, "nativeCheckAgeSeconds": now-lastNativeCheck,
         "parentHeartbeatTimeoutSeconds": heartbeatTimeout,
         "nativeCheckTimeoutSeconds": GuardTiming.nativeCheckTimeout,
         "parentReceiveGaps": parentGaps.value, "nativeCheckGaps": nativeGaps.value]
    }
    func progress(now: TimeInterval = monotonicNow()) -> [String: Any] {
        mutex.lock(); defer { mutex.unlock() }
        // Keep regular frames below PIPE_BUF even when Lua is briefly stalled.
        // Full gap histograms belong only in the one-shot incident record.
        return ["sequence": nativeSequence, "checkedAtUptime": lastNativeCheck,
                "health": ["parentSequence": parentSequence, "lastParentSentUptime": lastHeartbeat,
                           "parentHeartbeatAgeSeconds": now-lastHeartbeat,
                           "nativeCheckAgeSeconds": now-lastNativeCheck]]
    }
    @discardableResult
    func heartbeat(sequence: UInt64, sentAt: TimeInterval, now: TimeInterval = monotonicNow()) -> Bool {
        mutex.lock(); defer { mutex.unlock() }
        expireLocked(now: now)
        guard incidentReason == nil && !disarmed else { return false }
        guard sentAt.isFinite && sentAt >= lastHeartbeat && sentAt <= now && sequence > parentSequence else { return false }
        parentGaps.record(now-lastParentReceived)
        parentSequence = sequence; lastHeartbeat = sentAt; lastParentReceived = now
        return true // Never replace the sender timestamp with pipe delivery time.
    }
    // Called only after successful topology, online-display AND brightness checks.
    @discardableResult
    func completedCheck(now: TimeInterval = monotonicNow()) -> Bool {
        mutex.lock(); defer { mutex.unlock() }
        guard monitoring && incidentReason == nil && !disarmed else { return false }
        nativeGaps.record(now-lastNativeCheck)
        expireLocked(now: now)
        guard incidentReason == nil else { return false }
        lastNativeCheck = now; nativeSequence += 1
        return true
    }
    func disarm() { mutex.lock(); disarmed = true; mutex.unlock() }
    func trip(_ reason: String = "native display check failed") {
        mutex.lock()
        if incidentReason == nil { incidentReason = reason }
        mutex.unlock()
        check()
    }
    private func expireLocked(now: TimeInterval) {
        guard enabled && !disarmed && incidentReason == nil else { return }
        if monitoring && now-lastNativeCheck > GuardTiming.nativeCheckTimeout {
            incidentReason = "native display check progress timed out"
        } else if now-lastHeartbeat > heartbeatTimeout {
            incidentReason = monitoring ? "parent heartbeat timed out while armed" : "parent heartbeat timed out during display setup"
        }
    }
    func check(now: TimeInterval = monotonicNow()) {
        mutex.lock(); defer { mutex.unlock() }
        guard enabled && !disarmed else { return }
        expireLocked(now: now)
        guard let reason = incidentReason, !lockObserved else { return }
        if isLocked() { lockObserved = true; return }
        if requestedAt == nil { requestedAt = now }
        lockScreen() // Request the lock before any fallible diagnostics.
        if !incidentReported {
            incidentReported = true
            reportIncident(["reason": reason, "incidentId": incidentId,
                "requestedAtUptime": requestedAt!, "health": healthLocked(now: now)])
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
            let fields = buffer.split(separator: " ")
            if fields.count == 3 && fields[0] == "heartbeat",
               let sequence = UInt64(fields[1]), let sentAt = Double(fields[2]), sentAt.isFinite {
                guardWatchdog.heartbeat(sequence: sequence, sentAt: sentAt)
            } else if buffer == "arm", let arm { arm() }
            else if buffer == "disarm" { guardWatchdog.disarm(); disarm(); return }
            else { guardWatchdog.trip("invalid parent command") }
            buffer = ""
        } else if buffer.count < 128 { buffer.append(Character(UnicodeScalar(byte))) }
        else { guardWatchdog.trip("parent command exceeded size limit") }
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
        var locks = 0, locked = false, reports: [[String: Any]] = []
        let test = GuardWatchdog(lockScreen: { locks += 1 }, isLocked: { locked }, reportIncident: { reports.append($0) })
        test.enable(now: 100); precondition(test.beginMonitoring(now: 100))
        let progressFrame = try JSONSerialization.data(withJSONObject: test.progress(now: 100))
        precondition(progressFrame.count < 512)
        // A healthy native monitor outlives the old 2s parent budget, up to 10s.
        for index in 1...100 {
            let now = 100+Double(index)/10
            test.completedCheck(now: now); test.check(now: now); precondition(locks == 0)
        }
        test.completedCheck(now: 110.001); test.check(now: 110.001); precondition(locks == 1)
        precondition(reports.count == 1 && reports[0]["reason"] as? String == "parent heartbeat timed out while armed")
        test.trip("later brightness change"); precondition(reports.count == 1)
        precondition(reports[0]["incidentId"] as? String != nil && reports[0]["health"] != nil)
        locked = true; test.check(now: 111); locked = false
        let beforeReturn = locks; test.check(now: 112); precondition(locks == beforeReturn)
        precondition(!test.beginMonitoring(now: 112))
        // Parent traffic cannot conceal a stalled native display-monitor loop.
        var stalledLocks = 0, stalledReason = ""
        let stalled = GuardWatchdog(lockScreen: { stalledLocks += 1 }, isLocked: { false },
            reportIncident: { stalledReason = $0["reason"] as! String })
        stalled.enable(now: 10); precondition(stalled.beginMonitoring(now: 10))
        stalled.heartbeat(sequence: 1, sentAt: 12, now: 12); stalled.check(now: 12)
        precondition(stalledLocks == 0)
        stalled.heartbeat(sequence: 2, sentAt: 12.001, now: 12.001); stalled.check(now: 12.001)
        precondition(stalledLocks == 1 && stalledReason == "native display check progress timed out")
        // Buffered, duplicate, future or reordered heartbeats cannot renew freshness.
        var bufferedLocks = 0
        let buffered = GuardWatchdog(lockScreen: { bufferedLocks += 1 }, isLocked: { false })
        buffered.enable(now: 100); precondition(buffered.beginMonitoring(now: 100))
        for index in 1...9 { buffered.completedCheck(now: 100+Double(index)) }
        precondition(buffered.heartbeat(sequence: 1, sentAt: 101, now: 109))
        precondition(!buffered.heartbeat(sequence: 1, sentAt: 109, now: 109))
        precondition(!buffered.heartbeat(sequence: 2, sentAt: 120, now: 109))
        buffered.completedCheck(now: 110); buffered.completedCheck(now: 111)
        buffered.completedCheck(now: 111.001); buffered.check(now: 111.001)
        precondition(bufferedLocks == 1)
        // A late check/heartbeat/arm cannot erase an elapsed deadline between ticks.
        let late = GuardWatchdog(lockScreen: {}, isLocked: { false })
        late.enable(now: 100); precondition(late.beginMonitoring(now: 100))
        precondition(!late.completedCheck(now: 102.001))
        precondition(!late.heartbeat(sequence: 1, sentAt: 102.001, now: 102.001))
        let lateArm = GuardWatchdog(lockScreen: {}, isLocked: { false })
        lateArm.enable(now: 100, timeout: 25); precondition(!lateArm.beginMonitoring(now: 125.001))
        // Setup has a separate bounded budget; a late arm cannot reset an incident.
        var setupLocks = 0, setupReason = ""
        let setup = GuardWatchdog(lockScreen: { setupLocks += 1 }, isLocked: { false },
            reportIncident: { setupReason = $0["reason"] as! String })
        setup.enable(now: 10, timeout: 25); setup.check(now: 35); precondition(setupLocks == 0)
        setup.check(now: 35.001); precondition(setupLocks == 1)
        precondition(setupReason == "parent heartbeat timed out during display setup" && !setup.beginMonitoring(now: 36))
        let physical = GuardWatchdog(lockScreen: { setupLocks += 1 }, isLocked: { false })
        physical.enable(); precondition(physical.beginMonitoring()); physical.trip("brightness increased")
        precondition(setupLocks == 2)
        let disarmed = GuardWatchdog(lockScreen: { preconditionFailure("disarmed") }, isLocked: { false })
        disarmed.enable(); disarmed.disarm(); disarmed.trip()
        let externalLock = GuardWatchdog(lockScreen: { preconditionFailure("already locked") },
            isLocked: { true }, reportIncident: { _ in preconditionFailure("external lock must stay unknown") })
        externalLock.enable(); externalLock.trip("brightness rose after external lock")
        // Test the real parser without any desktop input or real lock invocation.
        var descriptors: [Int32] = [0, 0]
        precondition(pipe(&descriptors) == 0)
        let commands = GuardWatchdog(lockScreen: { preconditionFailure("disarm parser") }, isLocked: { false })
        commands.enable(); var acknowledged = false, didDisarm = false
        let input = Array("heartbeat 1 \(monotonicNow())\narm\ndisarm\n".utf8)
        _ = input.withUnsafeBytes { write(descriptors[1], $0.baseAddress, $0.count) }
        close(descriptors[1])
        consumeCommands(descriptors[0], commands, arm: { acknowledged = commands.beginMonitoring() }, disarm: { didDisarm = true })
        close(descriptors[0]); precondition(acknowledged && didDisarm)
        precondition(pipe(&descriptors) == 0)
        var eofLocks = 0
        let disconnected = GuardWatchdog(lockScreen: { eofLocks += 1 }, isLocked: { false })
        disconnected.enable(); close(descriptors[1]); consumeCommands(descriptors[0], disconnected, disarm: {})
        close(descriptors[0]); precondition(eofLocks == 1)
        // Main-thread monitoring stalls still lock from the independent queue.
        let signalled = DispatchSemaphore(value: 0)
        let asynchronous = GuardWatchdog(lockScreen: { signalled.signal() }, isLocked: { false })
        asynchronous.enable(); precondition(asynchronous.beginMonitoring(now: monotonicNow()-3))
        let independent = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "away-guard.test"))
        independent.schedule(deadline: .now(), repeating: .milliseconds(100))
        independent.setEventHandler { asynchronous.check() }; independent.resume()
        precondition(signalled.wait(timeout: .now()+1) == .success)
        asynchronous.disarm(); independent.cancel()
        _ = try lockFunction() // Resolve, never invoke, the actual API.
        emit("self_test_passed", ["cases": "10s parent loss, independent 2s native progress, immediate incidents, stale sequence/time, first cause, EOF/disarm, setup bounds, independent queue"])
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
            reportIncident: { emit("watchdog_lock", $0) })
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
        // topology failures/EOF still trip immediately. Start the independent 2s
        // native-progress budget only after the darkening handshake completes.
        guardWatchdog.enable(timeout: handshake ? 25 : GuardTiming.parentHeartbeatTimeout)
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
                    emit("armed", guardWatchdog.progress())
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
        let timer = Timer.scheduledTimer(withTimeInterval: GuardTiming.pollInterval, repeats: true) { _ in
            do {
                if try topology() != baseline || online() != [internalID] {
                    guardWatchdog.trip("physical or online topology changed")
                    emit("changed", ["reason": "physical or online topology changed", "online": try online(), "topology": try topology()])
                    return
                }
                let value = try brightness(internalID)
                if guardWatchdog.isMonitoring && value > 0 {
                    guardWatchdog.trip("brightness increased or unreadable: \(value)")
                    emit("changed", ["reason": "brightness increased or unreadable: \(value)"])
                    return
                }
                if guardWatchdog.completedCheck() { emit("heartbeat", guardWatchdog.progress()) }
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
