import Foundation
import ServiceManagement

private let helperBundleIdentifier = "com.jd.resolution-watcher.helper"
private let legacyLaunchAgentLabels = [
    "com.jd.resolution-watcher",
    "dev.local.resolution-watcher",
]

func installHelper() throws {
    try verifyBundledHelper()
    removeLegacyLaunchAgents()
    removeBundleProvenance()

    let service = SMAppService.loginItem(identifier: helperBundleIdentifier)
    try? service.unregister()
    try service.register()
}

func uninstallHelper() {
    try? SMAppService.loginItem(identifier: helperBundleIdentifier).unregister()
    removeLegacyLaunchAgents()
}

private func verifyBundledHelper() throws {
    let helperURL = Bundle.main.bundleURL
        .appendingPathComponent("Contents/Library/LoginItems/Resolution Watcher Helper.app")
        .appendingPathComponent("Contents/MacOS/Resolution Watcher Helper")

    guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
        throw RegistrationError.helperMissing(helperURL.path)
    }
}

private func removeLegacyLaunchAgents() {
    for label in legacyLaunchAgentLabels {
        let plistURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")

        try? runLaunchctl(["bootout", launchDomain(), plistURL.path])
        try? FileManager.default.removeItem(at: plistURL)
    }
}

private func removeBundleProvenance() {
    try? runXattr(["-dr", "com.apple.provenance", Bundle.main.bundleURL.path])
    try? runXattr(["-dr", "com.apple.quarantine", Bundle.main.bundleURL.path])
}

private func launchDomain() -> String {
    "gui/\(getuid())"
}

private func runLaunchctl(_ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        throw RegistrationError.launchctl(arguments.joined(separator: " "))
    }
}

private func runXattr(_ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
}

enum RegistrationError: Error, LocalizedError {
    case helperMissing(String)
    case launchctl(String)

    var errorDescription: String? {
        switch self {
        case .helperMissing(let path):
            return "helper missing: \(path)"
        case .launchctl(let command):
            return "launchctl failed: \(command)"
        }
    }
}
