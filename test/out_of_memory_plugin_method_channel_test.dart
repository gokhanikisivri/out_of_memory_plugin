import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:out_of_memory_plugin/out_of_memory_plugin_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelOutOfMemoryPlugin();
  const channel = MethodChannelOutOfMemoryPlugin.methodChannel;
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('getMemoryInfo returns the native map', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getMemoryInfo');
      return {'applicationUsedMemory': 120, 'availableMemory': 900, 'totalMemory': 4096, 'appRemainingMemory': 1800};
    });
    expect(await platform.getMemoryInfo(),
        {'applicationUsedMemory': 120, 'availableMemory': 900, 'totalMemory': 4096, 'appRemainingMemory': 1800});
  });

  test('getMemoryInfo returns empty map on PlatformException', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'x'));
    expect(await platform.getMemoryInfo(), isEmpty);
  });

  test('getMemoryInfo returns empty map when the plugin is missing', () async {
    // No mock handler -> MissingPluginException.
    expect(await platform.getMemoryInfo(), isEmpty);
  });

  test('getPreviousSessionReport returns the native map', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getPreviousSessionReport');
      return {'reason': 'outOfMemory', 'memoryWarningCount': 2};
    });
    expect(await platform.getPreviousSessionReport(), {'reason': 'outOfMemory', 'memoryWarningCount': 2});
  });

  test('does not call native code on other platforms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var called = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return null;
    });
    expect(await platform.getMemoryInfo(), isEmpty);
    expect(await platform.getPreviousSessionReport(), isEmpty);
    expect(await platform.onMemoryWarning.isEmpty, isTrue);
    expect(called, isFalse);
  });
}
