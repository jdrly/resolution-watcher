import AppKit
import Foundation

private enum WatcherState {
    case work
    case game
}

private final class ResolutionWatcher: NSObject {
    private let config: WatcherConfig
    private let switcher: DisplayModeSwitcher
    private let logger: Logger
    private var state: WatcherState = .work
    private var switchingToGame = false

    init(config: WatcherConfig, switcher: DisplayModeSwitcher, logger: Logger) {
        self.config = config
        self.switcher = switcher
        self.logger = logger
    }

    func run() {
        if isWatchedAppRunning() {
            logger.log("\(config.watchedBundleID) already running; switching to game mode")
            if switcher.setMode(config.gameMode) {
                state = .game
            }
        } else {
            logger.log("watcher started; waiting for \(config.watchedBundleID)")
        }

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self,
            selector: #selector(applicationWillLaunch(_:)),
            name: NSWorkspace.willLaunchApplicationNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(applicationLaunched(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(applicationTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        RunLoop.main.run()
    }

    @objc private func applicationWillLaunch(_ notification: Notification) {
        guard isWatchedApp(notification) else {
            return
        }

        switchToGameMode(reason: "\(config.watchedBundleID) launch requested; switching to game mode before app launch")
    }

    @objc private func applicationLaunched(_ notification: Notification) {
        guard isWatchedApp(notification) else {
            return
        }

        switchToGameMode(reason: "\(config.watchedBundleID) launched; switching to game mode")
    }

    @objc private func applicationTerminated(_ notification: Notification) {
        guard isWatchedApp(notification), state != .work, !isWatchedAppRunning() else {
            return
        }

        logger.log("\(config.watchedBundleID) closed; restoring work mode")
        if switcher.setMode(config.workMode) {
            state = .work
        }
    }

    private func switchToGameMode(reason: String) {
        guard state != .game, !switchingToGame else {
            return
        }

        switchingToGame = true
        defer {
            switchingToGame = false
        }

        logger.log(reason)
        if switcher.setMode(config.gameMode) {
            state = .game
        }
    }

    private func isWatchedApp(_ notification: Notification) -> Bool {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return false
        }

        return app.bundleIdentifier == config.watchedBundleID
    }

    private func isWatchedAppRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier == config.watchedBundleID && !app.isTerminated
        }
    }
}

let logger = Logger.makeDefault()

do {
    let config = try WatcherConfig.load()
    let switcher = try DisplayModeSwitcher.make(logger: logger)
    ResolutionWatcher(config: config, switcher: switcher, logger: logger).run()
} catch {
    logger.log(error.localizedDescription)
    exit(78)
}
