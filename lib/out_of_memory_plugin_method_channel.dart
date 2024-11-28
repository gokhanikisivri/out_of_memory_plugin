import 'dart:async';

import 'package:flutter/services.dart';

import 'out_of_memory_plugin_platform_interface.dart';

class MethodChannelOutOfMemoryPlugin extends OutOfMemoryPluginPlatform {
  static const MethodChannel _methodChannel = MethodChannel('out_of_memory_plugin');
  static const EventChannel _eventChannel = EventChannel('out_of_memory_plugin_events');

  @override
  Future<Map<String, int>> getMemoryInfo() async {
    var defaultValue = {"used": -1, "free": -1, "total": -1};
    try {
      var memoryInfo = await _methodChannel.invokeMapMethod<String, int>('getMemoryInfo');
      return memoryInfo ?? defaultValue;
    } on PlatformException catch (e) {
      return defaultValue;
    }
  }

  @override
  Stream<String> get onMemoryWarning {
    return _eventChannel.receiveBroadcastStream().cast<String>();
  }
}
