import 'package:out_of_memory_plugin/out_of_memory_plugin_platform_interface.dart';

class OutOfMemoryPlugin {
  static Future<MemoryInformationResult> getMemoryInfo() async {
    var result = await OutOfMemoryPluginPlatform.instance.getMemoryInfo();
    return MemoryInformationResult.fromMap(result);
  }

  static Stream<String> get onMemoryWarning {
    return OutOfMemoryPluginPlatform.instance.onMemoryWarning;
  }
}

class MemoryInformationResult {
  final int applicationUsedMemory;
  final int availableMemory;
  final int totalMemory;

  MemoryInformationResult({required this.applicationUsedMemory, required this.availableMemory, required this.totalMemory});

  // Map'ten MemoryInfo oluşturma
  factory MemoryInformationResult.fromMap(Map<String, dynamic> map) {
    return MemoryInformationResult(
      applicationUsedMemory: map['applicationUsedMemory'] ?? -1,
      availableMemory: map['availableMemory'] ?? -1,
      totalMemory: map['totalMemory'] ?? -1,
    );
  }
}
