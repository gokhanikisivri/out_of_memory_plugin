import Flutter
import Testing
import UIKit

@testable import out_of_memory_plugin

/// Covers every step of TerminationClassifier's decision order.
struct TerminationClassifierTests {
  private let version = "1.0.0+1"
  private let os = "18.0"

  private func state(
    appVersion: String = "1.0.0+1",
    osVersion: String = "18.0",
    isActive: Bool = true,
    cleanExit: Bool = false,
    debuggerAttached: Bool = false
  ) -> SessionState {
    SessionState(
      appVersion: appVersion, osVersion: osVersion, isActive: isActive, cleanExit: cleanExit,
      debuggerAttached: debuggerAttached, memoryWarningCount: 0, lastApplicationUsedMemory: 100,
      lastAppRemainingMemory: 10, lastSeenAt: 0)
  }

  private func classify(_ previous: SessionState?) -> TerminationReason {
    TerminationClassifier.classify(
      previous: previous, currentAppVersion: version, currentOSVersion: os)
  }

  @Test func noPreviousStateIsFirstLaunch() {
    #expect(classify(nil) == .firstLaunch)
  }

  @Test func cleanExitIsNormalExit() {
    #expect(classify(state(cleanExit: true)) == .normalExit)
    // Clean exit wins even if the app was active and the version changed.
    #expect(classify(state(appVersion: "0.9.0+1", cleanExit: true)) == .normalExit)
  }

  @Test func versionChangeIsAppUpdate() {
    #expect(classify(state(appVersion: "1.0.0+0")) == .appUpdate)
  }

  @Test func osChangeIsOsUpdate() {
    #expect(classify(state(osVersion: "17.5")) == .osUpdate)
  }

  @Test func debuggerIsDebugger() {
    #expect(classify(state(debuggerAttached: true)) == .debugger)
  }

  @Test func inactiveIsBackground() {
    #expect(classify(state(isActive: false)) == .background)
  }

  @Test func activeUnexplainedIsOutOfMemory() {
    #expect(classify(state()) == .outOfMemory)
  }
}

struct MemoryReaderTests {
  @Test func valuesAreReadable() {
    #expect(MemoryReader.applicationUsedMemory() > 0)
    #expect(MemoryReader.availableMemory() > 0)
    #expect(MemoryReader.availableMemory() < MemoryReader.totalMemory())
    #expect(MemoryReader.totalMemory() > 0)
    #expect(MemoryReader.appRemainingMemory() >= 0)
  }
}
