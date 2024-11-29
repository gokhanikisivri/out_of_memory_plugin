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
            do {
                result(try getMemoryInfo())
            } catch {
                result(["applicationUsedMemory": -1, "availableMemory": -1, "totalMemory": -1])
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    private func getMemoryInfo() throws -> [String: Int64] {
      // Uygulamanın kullandığı bellek
        var applicationUsedMemory: Int64 = 0

        // Cihazın toplam bellek
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let totalMemoryInMB = Int64(totalMemory) / 1024 / 1024 // Toplam bellek MB cinsinden

        // Bellek bilgilerini almak için gerekli yapı
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)

        // Uygulamanın kullandığı bellek bilgisi alınıyor
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            // Uygulamanın kullandığı bellek, resident_size
            applicationUsedMemory = Int64(info.resident_size) / 1024 / 1024 // MB cinsinden
        }

        // Cihazın boş bellek bilgisi (host_statistics64 ile)
        var stats = vm_statistics64()
        let HOST_VM_INFO64_COUNT = UInt32(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var countStats = HOST_VM_INFO64_COUNT
        let hostPort = mach_host_self()

        let statsPointer = withUnsafeMutablePointer(to: &stats) {
            UnsafeMutableRawPointer($0).assumingMemoryBound(to: integer_t.self)
        }

        // Cihazın boş belleğini alıyoruz
        guard host_statistics64(hostPort, HOST_VM_INFO64, statsPointer, &countStats) == KERN_SUCCESS else {
            return ["applicationUsedMemory": -1, "availableMemory": -1, "totalMemory": -1]
        }

        let pageSize = vm_kernel_page_size

        let freeMemory = Int64(stats.free_count) * Int64(pageSize) // Boş bellek
        // İnaktif bellek hesaplanıyor ve toplam kullanılabilir bellekten düşülüyor
        let inactiveMemory = Int64(stats.inactive_count) * Int64(pageSize)

        // Kullanılabilir bellek, free ve inactive belleklerin toplamıdır
        let availableMemory = freeMemory + inactiveMemory
        let availableMemoryInMB = availableMemory / 1024 / 1024

        // Sonuçları döndürüyoruz
        return [
            "applicationUsedMemory": applicationUsedMemory,        // Uygulamanın kullandığı bellek
            "availableMemory": availableMemoryInMB,    // Kullanılabilir bellek
            "totalMemory": totalMemoryInMB   // Cihazın toplam belleği
        ]
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
