import Flutter
import UIKit
import Darwin

public class OutOfMemoryPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "out_of_memory_plugin", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "out_of_memory_plugin_events", binaryMessenger: registrar.messenger())
        let instance = OutOfMemoryPlugin()

        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "getMemoryInfo" {
            result(getMemoryInfo())
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    private func getMemoryInfo() -> [String: Int64] {
        var stats = vm_statistics64()
        let HOST_VM_INFO64_COUNT = UInt32(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size) // Sabiti tanımlayın
        var count = HOST_VM_INFO64_COUNT
        let hostPort = mach_host_self()

        // `stats` için pointer oluştur ve dönüştür
        let statsPointer = withUnsafeMutablePointer(to: &stats) {
            UnsafeMutableRawPointer($0).assumingMemoryBound(to: integer_t.self)
        }

        guard host_statistics64(hostPort, HOST_VM_INFO64, statsPointer, &count) == KERN_SUCCESS else {
            return ["used": -1, "free": -1, "total": -1]
        }

        let pageSize = vm_kernel_page_size
        let free = Int64(stats.free_count) * Int64(pageSize)
        let active = Int64(stats.active_count) * Int64(pageSize)
        let inactive = Int64(stats.inactive_count) * Int64(pageSize)
        let wired = Int64(stats.wire_count) * Int64(pageSize)
        let used = active + inactive + wired
        let total = used + free

        // MB cinsinden döndürme
        let usedMB = used / 1024 / 1024
        let freeMB = free / 1024 / 1024
        let totalMB = total / 1024 / 1024

        return ["used": usedMB, "free": freeMB, "total": totalMB]
    }

    // MARK: - FlutterStreamHandler Methods
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events

        // Memory warning listener
        NotificationCenter.default.addObserver(self, selector: #selector(handleMemoryWarning), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil

        // Remove observer
        NotificationCenter.default.removeObserver(self, name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        return nil
    }

    @objc private func handleMemoryWarning() {
        if let eventSink = eventSink {
            // Flutter'a düz bir String mesajı gönderiyoruz
            eventSink("Memory warning received")
        }
    }
}
