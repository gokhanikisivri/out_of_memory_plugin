import Flutter
import UIKit

public class OutOfMemoryPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "out_of_memory_plugin", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "out_of_memory_plugin_events", binaryMessenger: registrar.messenger())
        let instance = OutOfMemoryPlugin()

        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)

        // Analyse the previous run and start recording this one. Runs once per process even if
        // several engines register the plugin.
        SessionTracker.shared.start()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getMemoryInfo":
            result(MemoryReader.snapshot())
        case "getPreviousSessionReport":
            result(SessionTracker.shared.previousSessionReport)
        case "markCleanExit":
            SessionTracker.shared.markCleanExit()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - FlutterStreamHandler Methods
    // Unchanged from the CocoaPods version (main branch): forwards memory warnings to Dart while someone listens. Memory warnings
    // are NOT OOMs (iOS may send many and the app usually survives); for OOMs use
    // getPreviousSessionReport. SessionTracker counts warnings independently of this stream.

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        NotificationCenter.default.addObserver(self, selector: #selector(handleMemoryWarning), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        NotificationCenter.default.removeObserver(self, name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        return nil
    }

    @objc private func handleMemoryWarning() {
        eventSink?("Memory warning received")
    }
}
