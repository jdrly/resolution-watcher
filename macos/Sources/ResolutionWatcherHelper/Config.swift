import Foundation

struct WatcherConfig {
    let watchedBundleID: String
    let prelaunchBundleIDs: Set<String>
    let prelaunchTimeoutSeconds: TimeInterval
    let gameMode: String
    let workMode: String

    static func load(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> WatcherConfig {
        let configURL = URL(fileURLWithPath: configPath(environment: environment))

        guard FileManager.default.isReadableFile(atPath: configURL.path) else {
            throw ConfigError.missing(configURL.path)
        }

        let content = try String(contentsOf: configURL, encoding: .utf8)
        var values: [String: String] = [
            "WATCHED_BUNDLE_ID": "com.blizzard.worldofwarcraft",
        ]

        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }

            guard let separatorIndex = line.firstIndex(of: "=") else {
                throw ConfigError.invalidLine(String(rawLine))
            }

            let key = line[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = line[line.index(after: separatorIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)

            if key.isEmpty {
                throw ConfigError.invalidLine(String(rawLine))
            }

            values[key] = unquote(rawValue)
        }

        let watchedBundleID = values["WATCHED_BUNDLE_ID"] ?? "com.blizzard.worldofwarcraft"
        let prelaunchBundleIDs = parsePrelaunchBundleIDs(
            values["PRELAUNCH_BUNDLE_IDS"],
            watchedBundleID: watchedBundleID
        )
        let prelaunchTimeoutSeconds = try parsePrelaunchTimeout(values["PRELAUNCH_TIMEOUT_SECONDS"])
        guard let gameMode = values["GAME_MODE"], !gameMode.isEmpty else {
            throw ConfigError.missingKey("GAME_MODE")
        }
        guard let workMode = values["WORK_MODE"], !workMode.isEmpty else {
            throw ConfigError.missingKey("WORK_MODE")
        }

        return WatcherConfig(
            watchedBundleID: watchedBundleID,
            prelaunchBundleIDs: prelaunchBundleIDs,
            prelaunchTimeoutSeconds: prelaunchTimeoutSeconds,
            gameMode: gameMode,
            workMode: workMode
        )
    }

    private static func configPath(environment: [String: String]) -> String {
        if let override = environment["RESOLUTION_WATCHER_CONFIG"], !override.isEmpty {
            return override
        }

        if let xdgConfigHome = environment["XDG_CONFIG_HOME"], !xdgConfigHome.isEmpty {
            return URL(fileURLWithPath: xdgConfigHome)
                .appendingPathComponent("resolution-watcher/config.zsh")
                .path
        }

        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".config/resolution-watcher/config.zsh")
            .path
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else {
            return value
        }

        let first = value.first
        let last = value.last

        if (first == "'" && last == "'") || (first == "\"" && last == "\"") {
            return String(value.dropFirst().dropLast())
        }

        return value
    }

    private static func parsePrelaunchBundleIDs(_ value: String?, watchedBundleID: String) -> Set<String> {
        guard let value else {
            if watchedBundleID == "com.blizzard.worldofwarcraft" {
                return ["net.battle.bootstrapper"]
            }

            return []
        }

        return Set(
            value.split { character in
                character == "," || character == " " || character == "\t"
            }
            .map(String.init)
            .filter { !$0.isEmpty }
        )
    }

    private static func parsePrelaunchTimeout(_ value: String?) throws -> TimeInterval {
        guard let value, !value.isEmpty else {
            return 180
        }

        guard let seconds = TimeInterval(value), seconds >= 0 else {
            throw ConfigError.invalidValue("PRELAUNCH_TIMEOUT_SECONDS")
        }

        return seconds
    }
}

enum ConfigError: Error, LocalizedError {
    case missing(String)
    case invalidLine(String)
    case missingKey(String)
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .missing(let path):
            return "missing config at \(path)"
        case .invalidLine(let line):
            return "invalid config line: \(line)"
        case .missingKey(let key):
            return "config must set \(key)"
        case .invalidValue(let key):
            return "invalid value for \(key)"
        }
    }
}
