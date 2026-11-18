import Foundation

/// How the previous run of the app ended.
///
/// iOS kills an app that exceeds its memory limit (OOM / jetsam) with SIGKILL: no code runs, so
/// neither this plugin nor Crashlytics can record anything at that moment. The only way to see
/// it is to look back on the next launch. The plugin keeps a small state file up to date while
/// the app runs (see `SessionState`) and, on the next launch, `TerminationClassifier` decides
/// which of these reasons explains how that state file was left.
enum TerminationReason: String {
    /// No state file from a previous run (first launch after install, or the file could not be
    /// read). Nothing can be said about the previous run.
    case firstLaunch

    /// The app ended normally: `applicationWillTerminate` was called, native `exit()` ran, or
    /// Dart called `OutOfMemoryPlugin.markCleanExit()` (needed before dart:io `exit()`, which
    /// skips native exit handlers). Not an OOM.
    case normalExit

    /// The previous run was a different app version/build. Installing an update kills the old
    /// process, so an unclean end is expected. Not an OOM.
    case appUpdate

    /// The previous run was on a different iOS version. An OS update restarts the device and
    /// kills every app. Not an OOM.
    case osUpdate

    /// A debugger (Xcode / `flutter run`) was attached. Stopping a debug session kills the app
    /// without any notification. Not an OOM.
    case debugger

    /// The app was not active (in the background, or the app switcher was open) when it died.
    /// iOS kills background apps all the time to free memory for *other* apps; that is normal and
    /// not caused by this app. A user swiping the app away in the app switcher also lands here,
    /// because the app resigns active before the switcher opens. Not counted as an OOM.
    case background

    /// The app was active in the foreground and died without any of the explanations above.
    /// This is how an OOM caused by this app looks.
    ///
    /// Limitations: this is a heuristic, not a signal from iOS.
    /// - A native crash also ends here. Exclude it on the Dart side with
    ///   `FirebaseCrashlytics.instance.didCrashOnPreviousExecution()`. The plugin deliberately
    ///   installs no crash handler of its own, because it would conflict with Crashlytics.
    /// - A watchdog kill (main thread blocked for too long), or the device switching off / the
    ///   battery dying while the app is open, also ends here. These are rare. A non-zero
    ///   `memoryWarningCount` or a low `lastAppRemainingMemory` is strong evidence for a real OOM.
    /// Apple's exact count is in Xcode Organizer → Terminations → Memory Limit; use it to
    /// cross-check the numbers.
    case outOfMemory
}

/// Pure decision logic, kept free of I/O so it can be unit tested.
enum TerminationClassifier {
    /// Decides how the previous run ended. The checks run in this order and the first match wins:
    ///
    /// 1. no previous state            → `firstLaunch`
    /// 2. clean exit recorded          → `normalExit`
    /// 3. app version/build changed    → `appUpdate`
    /// 4. iOS version changed          → `osUpdate`
    /// 5. debugger was attached        → `debugger`
    /// 6. app was not active           → `background`
    /// 7. otherwise (active, unexplained) → `outOfMemory`
    static func classify(
        previous: SessionState?,
        currentAppVersion: String,
        currentOSVersion: String
    ) -> TerminationReason {
        guard let previous = previous else { return .firstLaunch }
        if previous.cleanExit { return .normalExit }
        if previous.appVersion != currentAppVersion { return .appUpdate }
        if previous.osVersion != currentOSVersion { return .osUpdate }
        if previous.debuggerAttached { return .debugger }
        if !previous.isActive { return .background }
        return .outOfMemory
    }
}

/// What the plugin persists about the running session. Written atomically on every lifecycle
/// change, every memory warning and periodically while the app is active, so that after a
/// SIGKILL the file describes the last moments of the run.
struct SessionState: Codable, Equatable {
    /// `CFBundleShortVersionString+CFBundleVersion` of the run, e.g. `1.4.0+57`.
    var appVersion: String
    /// iOS version of the run, e.g. `18.1`.
    var osVersion: String
    /// The app was active (foreground, receiving events). Updated on
    /// didBecomeActive / willResignActive.
    var isActive: Bool
    /// `applicationWillTerminate`, native `exit()` or `markCleanExit` ran.
    var cleanExit: Bool
    /// A debugger was attached (checked on every write).
    var debuggerAttached: Bool
    /// Memory warnings received during the run.
    var memoryWarningCount: Int
    /// Last measured `applicationUsedMemory` (phys_footprint, MB).
    var lastApplicationUsedMemory: Int64
    /// Last measured `appRemainingMemory` (os_proc_available_memory, MB).
    var lastAppRemainingMemory: Int64
    /// When the state was last written (seconds since 1970).
    var lastSeenAt: TimeInterval
}
