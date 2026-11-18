import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'out_of_memory_plugin_method_channel.dart';

abstract class OutOfMemoryPluginPlatform extends PlatformInterface {
  /// Constructor for platform interface
  OutOfMemoryPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static OutOfMemoryPluginPlatform _instance = MethodChannelOutOfMemoryPlugin();

  /// Default instance to interact with
  static OutOfMemoryPluginPlatform get instance => _instance;

  /// Setter for instance
  static set instance(OutOfMemoryPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Raw memory figures from the native side (MB).
  Future<Map<String, int>> getMemoryInfo();

  /// Raw report about how the previous run of the app ended.
  Future<Map<String, dynamic>> getPreviousSessionReport();

  /// Records that the app is about to exit on purpose.
  Future<void> markCleanExit();

  /// Stream for memory warning events
  Stream<String> get onMemoryWarning;
}
