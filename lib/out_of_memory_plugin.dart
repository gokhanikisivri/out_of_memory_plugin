import 'package:out_of_memory_plugin/out_of_memory_plugin_platform_interface.dart';

class OutOfMemoryPlugin {
  static Future<Map<String, int>> getMemoryInfo() {
    return OutOfMemoryPluginPlatform.instance.getMemoryInfo();
  }

  static Stream<String> get onMemoryWarning {
    return OutOfMemoryPluginPlatform.instance.onMemoryWarning;
  }
}
