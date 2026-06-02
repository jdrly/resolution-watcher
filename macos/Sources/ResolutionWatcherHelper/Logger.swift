import Foundation

final class Logger {
    private let logURL: URL
    private let formatter: DateFormatter

    init(logURL: URL) {
        self.logURL = logURL
        formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }

    static func makeDefault(environment: [String: String] = ProcessInfo.processInfo.environment) -> Logger {
        if let override = environment["RESOLUTION_WATCHER_LOG"], !override.isEmpty {
            return Logger(logURL: URL(fileURLWithPath: override))
        }

        return Logger(
            logURL: URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Logs/resolution-watcher.log")
        )
    }

    func log(_ message: String) {
        let line = "\(formatter.string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }

        try? FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }

        guard let handle = try? FileHandle(forWritingTo: logURL) else {
            return
        }

        defer {
            try? handle.close()
        }

        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    }
}
