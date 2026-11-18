import Darwin
import Foundation
import UIKit

/// Keeps `SessionState` on disk up to date while the app runs and, once per process, works out
/// how the previous run ended (see `TerminationClassifier`).
///
/// One instance per process: `register(with:)` can run once per Flutter engine (background
/// isolates create extra engines), but the previous run must only be analysed once, before the
/// state file is overwritten.
final class SessionTracker {
    static let shared = SessionTracker()

    /// How often the memory figures are refreshed while the app is active. OOMs often happen
    /// without a memory warning, so periodic samples make `lastApplicationUsedMemory` /
    /// `lastAppRemainingMemory` describe the moments right before the kill.
    private static let sampleInterval: TimeInterval = 5

    private let lock = NSLock()
    private let fileURL: URL?
    private var state: SessionState
    private var started = false
    private var timer: Timer?

    /// The previous run's report, computed once in `start()`.
    private(set) var previousSessionReport: [String: Any] = [:]

    private init() {
        fileURL = SessionTracker.makeFileURL()
        state = SessionState(
            appVersion: SessionTracker.currentAppVersion(),
            osVersion: UIDevice.current.systemVersion,
            isActive: false,
            cleanExit: false,
            debuggerAttached: false,
            memoryWarningCount: 0,
            lastApplicationUsedMemory: -1,
            lastAppRemainingMemory: -1,
            lastSeenAt: Date().timeIntervalSince1970)
    }

    /// Must be called on the main thread (plugin registration runs there).
    func start() {
        lock.lock()
        if started {
            lock.unlock()
            return
        }
        started = true

        // 1. Look at what the previous run left behind, before overwriting it.
        let previous = readState()
        let reason = TerminationClassifier.classify(
            previous: previous,
            currentAppVersion: state.appVersion,
            currentOSVersion: state.osVersion)
        previousSessionReport = SessionTracker.makeReport(reason: reason, previous: previous)

        // 2. Start recording this run. Plugins may register after the app already became
        //    active (UIScene apps register in didInitializeImplicitFlutterEngine), so read the
        //    current state instead of waiting for didBecomeActive.
        state.isActive = UIApplication.shared.applicationState == .active
        lock.unlock()

        sampleAndWrite()
        if state.isActive { startTimer() }
        observeLifecycle()

        // A native exit() does not post willTerminate. A C callback cannot capture context, so it
        // goes through the shared instance. Note: dart:io `exit()` does NOT run atexit handlers;
        // Dart code must call `OutOfMemoryPlugin.markCleanExit()` before it.
        atexit { SessionTracker.shared.markCleanExit() }
    }

    // MARK: - Lifecycle

    private func observeLifecycle() {
        let center = NotificationCenter.default
        center.addObserver(
            self, selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil)
        center.addObserver(
            self, selector: #selector(willResignActive),
            name: UIApplication.willResignActiveNotification, object: nil)
        center.addObserver(
            self, selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        center.addObserver(
            self, selector: #selector(willTerminate),
            name: UIApplication.willTerminateNotification, object: nil)
    }

    @objc private func didBecomeActive() {
        update { $0.isActive = true }
        startTimer()
    }

    @objc private func willResignActive() {
        update { $0.isActive = false }
        stopTimer()
    }

    @objc private func didReceiveMemoryWarning() {
        update { $0.memoryWarningCount += 1 }
    }

    @objc private func willTerminate() {
        markCleanExit()
    }

    /// Records that this run is ending on purpose, so the next launch reports `normalExit`.
    func markCleanExit() {
        update { $0.cleanExit = true }
    }

    // MARK: - Sampling

    private func startTimer() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: SessionTracker.sampleInterval, repeats: true) {
            [weak self] _ in
            self?.sampleAndWrite()
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func sampleAndWrite() {
        update { _ in }
    }

    /// Applies `change`, refreshes the memory figures and debugger flag, and writes the file.
    private func update(_ change: (inout SessionState) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        change(&state)
        state.lastApplicationUsedMemory = MemoryReader.applicationUsedMemory()
        state.lastAppRemainingMemory = MemoryReader.appRemainingMemory()
        state.debuggerAttached = state.debuggerAttached || SessionTracker.isDebuggerAttached()
        state.lastSeenAt = Date().timeIntervalSince1970
        writeState()
    }

    // MARK: - Persistence

    private func readState() -> SessionState? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListDecoder().decode(SessionState.self, from: data)
    }

    /// Atomic write: after a SIGKILL the file holds either the old or the new state, never a
    /// half-written one. UserDefaults is not used because its flush timing is not guaranteed.
    private func writeState() {
        guard let url = fileURL,
            let data = try? PropertyListEncoder().encode(state)
        else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func makeFileURL() -> URL? {
        guard
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first
        else { return nil }
        var directory = base.appendingPathComponent("out_of_memory_plugin", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
        } catch {
            return nil
        }
        return directory.appendingPathComponent("session_state.plist")
    }

    // MARK: - Helpers

    private static func makeReport(reason: TerminationReason, previous: SessionState?)
        -> [String: Any]
    {
        var report: [String: Any] = [
            "reason": reason.rawValue,
            "wasOutOfMemory": reason == .outOfMemory,
            "memoryWarningCount": previous?.memoryWarningCount ?? 0,
            "lastApplicationUsedMemory": previous?.lastApplicationUsedMemory ?? -1,
            "lastAppRemainingMemory": previous?.lastAppRemainingMemory ?? -1,
        ]
        if let previous = previous {
            // Milliseconds since epoch; missing (null in Dart) for firstLaunch.
            report["lastSeenAt"] = Int64(previous.lastSeenAt * 1000)
        }
        return report
    }

    private static func currentAppVersion() -> String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version)+\(build)"
    }

    /// True when a debugger is attached to this process (`P_TRACED`).
    private static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
}
