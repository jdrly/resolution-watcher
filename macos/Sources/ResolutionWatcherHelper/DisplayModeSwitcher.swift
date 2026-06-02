import Foundation

final class DisplayModeSwitcher {
    private let displayplacerURL: URL
    private let logger: Logger

    init(displayplacerURL: URL, logger: Logger) {
        self.displayplacerURL = displayplacerURL
        self.logger = logger
    }

    static func make(logger: Logger, environment: [String: String] = ProcessInfo.processInfo.environment) throws -> DisplayModeSwitcher {
        let fileManager = FileManager.default

        if let override = environment["RESOLUTION_WATCHER_DISPLAYPLACER"], !override.isEmpty {
            guard fileManager.isExecutableFile(atPath: override) else {
                throw DisplayModeError.displayplacerMissing(override)
            }
            return DisplayModeSwitcher(displayplacerURL: URL(fileURLWithPath: override), logger: logger)
        }

        for path in ["/opt/homebrew/bin/displayplacer", "/usr/local/bin/displayplacer"] {
            if fileManager.isExecutableFile(atPath: path) {
                return DisplayModeSwitcher(displayplacerURL: URL(fileURLWithPath: path), logger: logger)
            }
        }

        throw DisplayModeError.displayplacerMissing("/opt/homebrew/bin/displayplacer or /usr/local/bin/displayplacer")
    }

    func setMode(_ mode: String) -> Bool {
        let process = Process()
        let output = Pipe()
        process.executableURL = displayplacerURL
        process.arguments = [mode]
        process.standardOutput = output
        process.standardError = output

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            logger.log("displayplacer failed to start: \(error.localizedDescription)")
            return false
        }

        let outputText = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if process.terminationStatus != 0 {
            if let outputText, !outputText.isEmpty {
                logger.log("displayplacer failed exit \(process.terminationStatus): \(outputText)")
            } else {
                logger.log("displayplacer failed exit \(process.terminationStatus)")
            }
            return false
        }

        if let outputText, !outputText.isEmpty {
            logger.log(outputText)
        }

        return true
    }
}

enum DisplayModeError: Error, LocalizedError {
    case displayplacerMissing(String)

    var errorDescription: String? {
        switch self {
        case .displayplacerMissing(let path):
            return "displayplacer missing at \(path)"
        }
    }
}
