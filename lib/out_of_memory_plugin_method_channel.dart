import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'out_of_memory_plugin_platform_interface.dart';

class MethodChannelOutOfMemoryPlugin extends OutOfMemoryPluginPlatform {
  @visibleForTesting
  static const MethodChannel methodChannel = MethodChannel('out_of_memory_plugin');
  static const EventChannel _eventChannel = EventChannel('out_of_memory_plugin_events');

  /// The plugin only has an iOS implementation; other platforms get default values.
  bool get _isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<Map<String, int>> getMemoryInfo() async {
    if (!_isSupported) return const {};
    try {
      return await methodChannel.invokeMapMethod<String, int>('getMemoryInfo') ?? const {};
    } on PlatformException {
      return const {};
    } on MissingPluginException {
      return const {};
    }
  }

  @override
  Future<Map<String, dynamic>> getPreviousSessionReport() async {
    if (!_isSupported) return const {};
    try {
      return await methodChannel.invokeMapMethod<String, dynamic>('getPreviousSessionReport') ?? const {};
    } on PlatformException {
      return const {};
    } on MissingPluginException {
      return const {};
    }
  }

  @override
  Future<void> markCleanExit() async {
    if (!_isSupported) return;
    try {
      await methodChannel.invokeMethod<void>('markCleanExit');
    } on PlatformException {
      // Best effort.
    } on MissingPluginException {
      // Best effort.
    }
  }

  @override
  Stream<String> get onMemoryWarning {
    if (!_isSupported) return const Stream.empty();
    return _eventChannel.receiveBroadcastStream().cast<String>();
  }
}
