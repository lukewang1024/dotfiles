// Session-only display control. Private symbols are checked at runtime.
import Foundation
import CoreGraphics
import Darwin

struct Failure: Error { let message: String }
func emit(_ event: String, _ fields: [String: Any] = [:]) {
    var value = fields; value["event"] = event
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) {
        FileHandle.standardOutput.write(data + Data([10]))
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
    if armed && !flags.contains(.beginConfigurationFlag) { emit("changed", ["reason": "display reconfiguration", "displayID": id, "flags": flags.rawValue]) }
}
do {
    let args = Array(CommandLine.arguments.dropFirst())
    switch args.first {
    case "status":
        emit("status", ["topology": try topology(), "online": try online(), "autoBrightness": try autoBrightness(internalDisplay())])
    case "restore":
        let identities = args.dropFirst().filter { !$0.hasPrefix("--auto-brightness=") }
        try restore(Array(identities))
        if let setting = args.first(where: { $0.hasPrefix("--auto-brightness=") }) {
            _ = try autoBrightness(internalDisplay(), set: setting == "--auto-brightness=on")
        }
        emit("restored")
    case "watch":
        let ids = try displays()
        guard let internalID = ids.first(where: { CGDisplayIsBuiltin($0) != 0 && CGDisplayIsOnline($0) != 0 }) else {
            throw Failure(message: "Open the MacBook lid first")
        }
        let baseline = try topology()
        let external = ids.filter { CGDisplayIsBuiltin($0) == 0 && CGDisplayIsOnline($0) != 0 }
        let saved = external.map { identity($0) }
        _ = try symbol("SLSConfigureDisplayEnabled", Enable.self)
        let automatic = try autoBrightness(internalID)
        emit("snapshot", ["external": saved, "internal": try uuid(internalID), "autoBrightness": automatic])
        // Hammerspoon must persist the snapshot before allowing any display changes.
        guard readLine() == "disable" else { throw Failure(message: "No disable authorization") }
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
                    emit("changed", ["reason": "physical or online topology changed", "online": try online(), "topology": try topology()])
                }
                emit("heartbeat")
            } catch { emit("error", ["reason": String(describing: error)]); exit(1) }
        }
        RunLoop.current.add(timer, forMode: .common)
        RunLoop.current.run()
    default: throw Failure(message: "Usage: away-guard-display status|watch|restore [IDENTITY ...]")
    }
} catch {
    emit("error", ["reason": (error as? Failure)?.message ?? String(describing: error)])
    exit(1)
}
