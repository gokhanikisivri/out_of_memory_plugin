import Darwin
import Foundation
import os

/// Reads memory figures from the kernel. Every value is in megabytes (MB); `-1` means the
/// value could not be read.
enum MemoryReader {
    private static let bytesPerMB: Int64 = 1024 * 1024

    /// Memory used by this app (`TASK_VM_INFO.phys_footprint`).
    ///
    /// This is the number iOS compares against the app's memory limit when it decides to kill
    /// the app (jetsam), and the same number Xcode's memory gauge shows. `resident_size`, which
    /// the CocoaPods version (main branch) used, ignores compressed memory and is not what jetsam looks at.
    static func applicationUsedMemory() -> Int64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        return Int64(info.phys_footprint) / bytesPerMB
    }

    /// RAM that is currently available on the whole device (`host_statistics64`).
    ///
    /// Computed as `(free + speculative + inactive) × page size`: free pages plus pages the
    /// system can reclaim immediately. iOS has no exact "available" figure for the whole device,
    /// so this is an approximation, but it is the standard one.
    static func availableMemory() -> Int64 {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        // mach_host_self() hands out a send right; release it so repeated calls don't leak ports.
        defer { mach_port_deallocate(mach_task_self_, host) }

        // The kernel call happens inside the closure so the pointer never outlives `stats`.
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }

        let pages = Int64(stats.free_count) + Int64(stats.speculative_count)
            + Int64(stats.inactive_count)
        return pages * Int64(vm_kernel_page_size) / bytesPerMB
    }

    /// Physical RAM of the device (`ProcessInfo.physicalMemory`).
    static func totalMemory() -> Int64 {
        return Int64(ProcessInfo.processInfo.physicalMemory) / bytesPerMB
    }

    /// How much more memory this app can allocate before iOS kills it
    /// (`os_proc_available_memory()`). When this reaches 0 the app is terminated for exceeding
    /// its memory limit. Returns 0 on the simulator, which has no per-app limit.
    static func appRemainingMemory() -> Int64 {
        return Int64(os_proc_available_memory()) / bytesPerMB
    }

    /// The map returned to Dart by `getMemoryInfo`.
    static func snapshot() -> [String: Int64] {
        return [
            "applicationUsedMemory": applicationUsedMemory(),
            "availableMemory": availableMemory(),
            "totalMemory": totalMemory(),
            "appRemainingMemory": appRemainingMemory(),
        ]
    }
}
