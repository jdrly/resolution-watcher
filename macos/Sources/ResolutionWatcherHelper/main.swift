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
    private let windowPositioner: WindowPositioner
    private var state: WatcherState = .work
    private var switchingToGame = false
    private var prelaunchPending = false
    private var prelaunchRestoreTimer: Timer?
    private var windowPositionTimer: Timer?
    private var windowPositionAttempts = 0

    init(config: WatcherConfig, switcher: DisplayModeSwitcher, logger: Logger, windowPositioner: WindowPositioner) {
        self.config = config
        self.switcher = switcher
        self.logger = logger
        self.windowPositioner = windowPositioner
    }

    func run() {
        if isWatchedAppRunning() {
            logger.log("\(config.watchedBundleID) already running; switching to game mode")
            if switcher.setMode(config.gameMode) {
                state = .game
                scheduleWatchedWindowPositioning()
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
        if isWatchedApp(notification) {
            clearPrelaunchPending()
            switchToGameMode(reason: "\(config.watchedBundleID) launch requested; switching to game mode before app launch")
            scheduleWatchedWindowPositioning()
            return
        }

        if isPrelaunchApp(notification) {
            prelaunchPending = true
            switchToGameMode(reason: "prelaunch app detected; switching to game mode before \(config.watchedBundleID)")
            schedulePrelaunchRestore()
        }
    }

    @objc private func applicationLaunched(_ notification: Notification) {
        guard isWatchedApp(notification) else {
            return
        }

        clearPrelaunchPending()
        switchToGameMode(reason: "\(config.watchedBundleID) launched; switching to game mode")
        scheduleWatchedWindowPositioning()
    }

    @objc private func applicationTerminated(_ notification: Notification) {
        guard isWatchedApp(notification), state != .work, !isWatchedAppRunning() else {
            return
        }

        clearPrelaunchPending()
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

    private func isPrelaunchApp(_ notification: Notification) -> Bool {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleIdentifier = app.bundleIdentifier else {
            return false
        }

        return config.prelaunchBundleIDs.contains(bundleIdentifier)
    }

    private func isWatchedAppRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier == config.watchedBundleID && !app.isTerminated
        }
    }

    private func schedulePrelaunchRestore() {
        prelaunchRestoreTimer?.invalidate()

        guard config.prelaunchTimeoutSeconds > 0 else {
            return
        }

        prelaunchRestoreTimer = Timer.scheduledTimer(withTimeInterval: config.prelaunchTimeoutSeconds, repeats: false) { [weak self] _ in
            self?.restoreWorkModeAfterPrelaunchTimeout()
        }
    }

    private func clearPrelaunchPending() {
        prelaunchPending = false
        prelaunchRestoreTimer?.invalidate()
        prelaunchRestoreTimer = nil
    }

    private func restoreWorkModeAfterPrelaunchTimeout() {
        guard prelaunchPending, state != .work, !isWatchedAppRunning() else {
            return
        }

        clearPrelaunchPending()
        logger.log("\(config.watchedBundleID) did not launch after prelaunch trigger; restoring work mode")
        if switcher.setMode(config.workMode) {
            state = .work
        }
    }

    private func scheduleWatchedWindowPositioning() {
        windowPositionTimer?.invalidate()
        windowPositionAttempts = 0
        windowPositionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            self.windowPositionAttempts += 1
            if self.windowPositioner.positionWindows(bundleIdentifier: self.config.watchedBundleID)
                || self.windowPositionAttempts >= 20 {
                timer.invalidate()
                self.windowPositionTimer = nil
            }
        }
    }
}

let logger = Logger.makeDefault()

do {
    let config = try WatcherConfig.load()
    let switcher = try DisplayModeSwitcher.make(logger: logger)
    let windowPositioner = WindowPositioner(logger: logger)
    ResolutionWatcher(
        config: config,
        switcher: switcher,
        logger: logger,
        windowPositioner: windowPositioner
    ).run()
} catch {
    logger.log(error.localizedDescription)
    exit(78)
}
