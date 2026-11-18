## 2.0.0

Breaking:
* iOS integration is Swift Package Manager only. The CocoaPods podspec was removed; use the `main` branch
  (0.0.1) for CocoaPods projects. Minimum iOS version is 15.0.
* `applicationUsedMemory` now reports `phys_footprint` (what Xcode shows and what iOS uses to kill
  the app) instead of `resident_size`.
* `OutOfMemoryPluginPlatform` has new abstract members (`getPreviousSessionReport`,
  `markCleanExit`).

New:
* `OutOfMemoryPlugin.getPreviousSessionReport()`: detects whether the previous run was killed
  while active in the foreground (OOM), with the memory figures measured right before the kill.
* `OutOfMemoryPlugin.markCleanExit()`: call before dart:io `exit()`.
* `MemoryInformationResult.appRemainingMemory`: how much more the app can allocate before iOS
  kills it (`os_proc_available_memory`).

Fixes:
* `availableMemory` now includes speculative pages; fixed a dangling pointer and a Mach port leak in
  its calculation.
* Dart side no longer throws on platforms other than iOS (`MissingPluginException`).
* Privacy manifest is now bundled.

## 0.0.1 (`main` branch)

* CocoaPods version. Memory info and memory warning stream.
