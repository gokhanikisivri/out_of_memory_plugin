import 'package:out_of_memory_plugin/out_of_memory_plugin_platform_interface.dart';

class OutOfMemoryPlugin {
  /// Current memory figures (MB). Can be called at any time.
  ///
  /// Fields that could not be read are `-1`. On platforms other than iOS every field is `-1`.
  static Future<MemoryInformationResult> getMemoryInfo() async {
    var result = await OutOfMemoryPluginPlatform.instance.getMemoryInfo();
    return MemoryInformationResult.fromMap(result);
  }

  /// How the previous run of the app ended. Call it once at startup.
  ///
  /// iOS kills an app that exceeds its memory limit with SIGKILL, so nothing (not even
  /// Crashlytics) can record the OOM when it happens. The plugin keeps a small state file up to
  /// date while the app runs and inspects it on the next launch. See [PreviousSessionReport] and
  /// [TerminationReason] for how the decision is made.
  ///
  /// The result is computed once per process; calling it again returns the same report.
  ///
  /// ```dart
  /// final report = await OutOfMemoryPlugin.getPreviousSessionReport();
  /// if (report.wasOutOfMemory &&
  ///     !await FirebaseCrashlytics.instance.didCrashOnPreviousExecution()) {
  ///   FirebaseCrashlytics.instance.recordError('OutOfMemory', null, ...);
  /// }
  /// ```
  static Future<PreviousSessionReport> getPreviousSessionReport() async {
    var result = await OutOfMemoryPluginPlatform.instance.getPreviousSessionReport();
    return PreviousSessionReport.fromMap(result);
  }

  /// Call this right before closing the app yourself with dart:io `exit()`.
  ///
  /// dart:io `exit()` ends the process without running native exit handlers, so without this
  /// call the next launch cannot tell a deliberate exit from an OOM and reports
  /// [TerminationReason.outOfMemory]. Normal iOS terminations (`applicationWillTerminate`) and
  /// native `exit()` are detected automatically.
  ///
  /// ```dart
  /// await OutOfMemoryPlugin.markCleanExit();
  /// exit(0);
  /// ```
  static Future<void> markCleanExit() {
    return OutOfMemoryPluginPlatform.instance.markCleanExit();
  }

  /// iOS memory warnings (`didReceiveMemoryWarningNotification`).
  ///
  /// A memory warning is NOT an OOM: iOS can send many per session and the app usually keeps
  /// running. Don't log these as OOMs; use [getPreviousSessionReport] for that.
  static Stream<String> get onMemoryWarning {
    return OutOfMemoryPluginPlatform.instance.onMemoryWarning;
  }
}

/// Memory figures returned by [OutOfMemoryPlugin.getMemoryInfo]. All values are in MB; `-1`
/// means the value could not be read.
class MemoryInformationResult {
  /// Memory used by this app: `phys_footprint` from `TASK_VM_INFO`.
  ///
  /// The same number Xcode's memory gauge shows, and the one iOS compares against the app's
  /// limit when it decides to kill it.
  final int applicationUsedMemory;

  /// RAM currently available on the whole device: `(free + speculative + inactive) × page size`
  /// from `host_statistics64`. iOS has no exact device-wide figure, so this is an approximation.
  final int availableMemory;

  /// Physical RAM of the device: `ProcessInfo.physicalMemory`.
  final int totalMemory;

  /// How much more memory this app can use before iOS kills it: `os_proc_available_memory()`.
  ///
  /// When this reaches 0 the app is terminated (OOM). Always 0 on the simulator, which has no
  /// per-app limit.
  final int appRemainingMemory;

  MemoryInformationResult({
    required this.applicationUsedMemory,
    required this.availableMemory,
    required this.totalMemory,
    this.appRemainingMemory = -1,
  });

  factory MemoryInformationResult.fromMap(Map<String, dynamic> map) {
    return MemoryInformationResult(
      applicationUsedMemory: map['applicationUsedMemory'] ?? -1,
      availableMemory: map['availableMemory'] ?? -1,
      totalMemory: map['totalMemory'] ?? -1,
      appRemainingMemory: map['appRemainingMemory'] ?? -1,
    );
  }

  @override
  String toString() =>
      'MemoryInformationResult(applicationUsedMemory: $applicationUsedMemory, availableMemory: $availableMemory, '
      'totalMemory: $totalMemory, appRemainingMemory: $appRemainingMemory)';
}

/// How the previous run ended. Checked in this order on the native side; the first match wins:
///
/// 1. [firstLaunch]  – no record of a previous run
/// 2. [normalExit]   – the app terminated normally
/// 3. [appUpdate]    – the app version/build changed
/// 4. [osUpdate]     – the iOS version changed
/// 5. [debugger]     – a debugger was attached
/// 6. [background]   – the app was not active when it died
/// 7. [outOfMemory]  – active in the foreground and died without explanation
enum TerminationReason {
  /// No state file from a previous run (first launch after install, or the file could not be
  /// read). Nothing can be said about the previous run.
  firstLaunch,

  /// `applicationWillTerminate` was called, native `exit()` ran, or the app called
  /// [OutOfMemoryPlugin.markCleanExit] (required before dart:io `exit()`). Not an OOM.
  normalExit,

  /// The previous run was a different app version/build. Installing an update kills the old
  /// process, so an unclean end is expected. Not an OOM.
  appUpdate,

  /// The previous run was on a different iOS version. An OS update restarts the device. Not an
  /// OOM.
  osUpdate,

  /// A debugger (Xcode / `flutter run`) was attached. Stopping a debug session kills the app.
  /// Not an OOM.
  debugger,

  /// The app was not active (in the background, or the app switcher was open) when it died.
  /// iOS routinely kills background apps to free memory for *other* apps, which is not caused
  /// by this app. A user swiping the app away in the app switcher also lands here. Not an OOM.
  background,

  /// The app was active in the foreground and died without any of the explanations above. This
  /// is how an OOM caused by this app looks.
  ///
  /// Limitations (it is a heuristic, not a signal from iOS):
  /// * A native crash also ends here: exclude it with
  ///   `FirebaseCrashlytics.instance.didCrashOnPreviousExecution()`.
  /// * A watchdog kill (main thread blocked too long), or the device switching off / the battery
  ///   dying while the app is open, also ends here. These are rare. A non-zero
  ///   [PreviousSessionReport.memoryWarningCount] or a low
  ///   [PreviousSessionReport.lastAppRemainingMemory] is strong evidence for a real OOM.
  ///
  /// Apple's exact count is in Xcode Organizer → Terminations → Memory Limit.
  outOfMemory,

  /// The native side returned a value this Dart version does not know (or no data at all, e.g.
  /// on platforms other than iOS).
  unknown;

  static TerminationReason fromName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return unknown;
  }
}

/// Report returned by [OutOfMemoryPlugin.getPreviousSessionReport].
class PreviousSessionReport {
  /// How the previous run ended. See [TerminationReason].
  final TerminationReason reason;

  /// True when [reason] is [TerminationReason.outOfMemory].
  bool get wasOutOfMemory => reason == TerminationReason.outOfMemory;

  /// Memory warnings received during the previous run.
  final int memoryWarningCount;

  /// Last measured [MemoryInformationResult.applicationUsedMemory] of the previous run (MB). The
  /// plugin samples it every 5 seconds while the app is active and on every memory warning or
  /// lifecycle change. `-1` when unknown.
  final int lastApplicationUsedMemory;

  /// Last measured [MemoryInformationResult.appRemainingMemory] of the previous run (MB): how far
  /// the app was from its memory limit. A value close to 0 points to a real OOM. `-1` when
  /// unknown.
  final int lastAppRemainingMemory;

  /// When the previous run was last seen alive (last state write). `null` for
  /// [TerminationReason.firstLaunch].
  final DateTime? lastSeenAt;

  PreviousSessionReport({
    required this.reason,
    required this.memoryWarningCount,
    required this.lastApplicationUsedMemory,
    required this.lastAppRemainingMemory,
    required this.lastSeenAt,
  });

  factory PreviousSessionReport.fromMap(Map<String, dynamic> map) {
    final lastSeenAt = map['lastSeenAt'];
    return PreviousSessionReport(
      reason: TerminationReason.fromName(map['reason'] as String?),
      memoryWarningCount: map['memoryWarningCount'] ?? 0,
      lastApplicationUsedMemory: map['lastApplicationUsedMemory'] ?? -1,
      lastAppRemainingMemory: map['lastAppRemainingMemory'] ?? -1,
      lastSeenAt: lastSeenAt is int ? DateTime.fromMillisecondsSinceEpoch(lastSeenAt) : null,
    );
  }

  @override
  String toString() =>
      'PreviousSessionReport(reason: ${reason.name}, memoryWarningCount: $memoryWarningCount, '
      'lastApplicationUsedMemory: $lastApplicationUsedMemory, lastAppRemainingMemory: $lastAppRemainingMemory, '
      'lastSeenAt: $lastSeenAt)';
}
