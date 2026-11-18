# out_of_memory_plugin

iOS plugin that

* reports memory figures on demand (`getMemoryInfo`),
* forwards iOS memory warnings (`onMemoryWarning`),
* **detects out-of-memory (OOM / jetsam) terminations** that Firebase Crashlytics cannot report
  (`getPreviousSessionReport`).

## Versions

| Branch | Version | iOS integration |
|---|---|---|
| `main` | 0.0.1 | CocoaPods |
| `spm_update` | 2.x | Swift Package Manager only, iOS 15+ |

```yaml
out_of_memory_plugin:
  git:
    url: https://github.com/gokhanikisivri/out_of_memory_plugin.git
    ref: spm_update   # or: main (old CocoaPods version)
```

After changing `ref`, run `flutter pub upgrade out_of_memory_plugin` (pubspec.lock pins the commit).

## Logging OOMs to Crashlytics

iOS kills an app that exceeds its memory limit with SIGKILL. No code runs at that moment, which is
why Crashlytics never sees it. The plugin keeps a small state file up to date while the app runs and,
on the next launch, decides how the previous run ended. Call it once at startup, after Firebase is
initialised:

```dart
final report = await OutOfMemoryPlugin.getPreviousSessionReport();
if (report.wasOutOfMemory &&
    !await FirebaseCrashlytics.instance.didCrashOnPreviousExecution()) {
  await FirebaseCrashlytics.instance.recordError(
    'OutOfMemory',
    null,
    reason: 'previous session was killed by iOS (out of memory)',
    information: [
      'memoryWarningCount: ${report.memoryWarningCount}',
      'lastApplicationUsedMemory: ${report.lastApplicationUsedMemory} MB',
      'lastAppRemainingMemory: ${report.lastAppRemainingMemory} MB',
      'lastSeenAt: ${report.lastSeenAt}',
    ],
  );
}
```

This produces **one record per OOM**. Do not log `onMemoryWarning` events as OOMs: iOS can send many
warnings per session and the app usually survives them.

If the app closes itself with dart:io `exit()`, call `await OutOfMemoryPlugin.markCleanExit()` first.
dart:io `exit()` skips native exit handlers, so without that call the exit looks like an OOM.

### How the previous run is classified

Checked in this order; the first match wins:

| # | Condition | `reason` | OOM? |
|---|---|---|---|
| 1 | No record of a previous run | `firstLaunch` | no |
| 2 | `applicationWillTerminate`, native `exit()` or `markCleanExit()` | `normalExit` | no |
| 3 | App version/build changed (update kills the old process) | `appUpdate` | no |
| 4 | iOS version changed | `osUpdate` | no |
| 5 | A debugger was attached (Xcode / `flutter run` stop) | `debugger` | no |
| 6 | App was not active: background, or app switcher open (includes the user swiping it away). iOS kills background apps to make room for *other* apps. | `background` | no |
| 7 | Active in the foreground and died without explanation | `outOfMemory` | **yes** |

### Limitations

This is a heuristic (the same approach Sentry, Bugsnag and Facebook use), not a signal from iOS:

* A native crash also ends in step 7. Exclude it with `didCrashOnPreviousExecution()` as shown above.
* A watchdog kill (main thread blocked too long), or the device switching off / the battery dying
  while the app is open, also ends in step 7. These are rare. A non-zero `memoryWarningCount` or a
  low `lastAppRemainingMemory` is strong evidence for a real OOM.
* Apple's exact count is in Xcode Organizer → Terminations → **Memory Limit**. Use it to cross-check.

## Memory info

`OutOfMemoryPlugin.getMemoryInfo()` can be called at any time. All values are in MB; `-1` means the
value could not be read.

| Field | Meaning | Source |
|---|---|---|
| `applicationUsedMemory` | Memory used by the app (same as Xcode's gauge, what iOS uses to kill the app) | `TASK_VM_INFO.phys_footprint` |
| `availableMemory` | RAM currently available on the device (approximation) | `host_statistics64`: free + speculative + inactive |
| `totalMemory` | Physical RAM of the device | `ProcessInfo.physicalMemory` |
| `appRemainingMemory` | How much more the app can allocate before iOS kills it (0 on the simulator) | `os_proc_available_memory()` |
