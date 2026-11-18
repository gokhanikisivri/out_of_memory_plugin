import 'package:flutter_test/flutter_test.dart';
import 'package:out_of_memory_plugin/out_of_memory_plugin.dart';
import 'package:out_of_memory_plugin/out_of_memory_plugin_method_channel.dart';
import 'package:out_of_memory_plugin/out_of_memory_plugin_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePlatform with MockPlatformInterfaceMixin implements OutOfMemoryPluginPlatform {
  Map<String, int> memoryInfo = {};
  Map<String, dynamic> report = {};

  @override
  Future<Map<String, int>> getMemoryInfo() async => memoryInfo;

  @override
  Future<Map<String, dynamic>> getPreviousSessionReport() async => report;

  bool cleanExitMarked = false;

  @override
  Future<void> markCleanExit() async => cleanExitMarked = true;

  @override
  Stream<String> get onMemoryWarning => Stream.value('Memory warning received');
}

void main() {
  test('$MethodChannelOutOfMemoryPlugin is the default instance', () {
    expect(OutOfMemoryPluginPlatform.instance, isA<MethodChannelOutOfMemoryPlugin>());
  });

  group('with fake platform', () {
    late FakePlatform fake;

    setUp(() {
      fake = FakePlatform();
      OutOfMemoryPluginPlatform.instance = fake;
    });

    test('getMemoryInfo maps all fields', () async {
      fake.memoryInfo = {'applicationUsedMemory': 120, 'availableMemory': 900, 'totalMemory': 4096, 'appRemainingMemory': 1800};
      final info = await OutOfMemoryPlugin.getMemoryInfo();
      expect(info.applicationUsedMemory, 120);
      expect(info.availableMemory, 900);
      expect(info.totalMemory, 4096);
      expect(info.appRemainingMemory, 1800);
    });

    test('getMemoryInfo falls back to -1', () async {
      final info = await OutOfMemoryPlugin.getMemoryInfo();
      expect(info.applicationUsedMemory, -1);
      expect(info.availableMemory, -1);
      expect(info.totalMemory, -1);
      expect(info.appRemainingMemory, -1);
    });

    test('getPreviousSessionReport maps an OOM report', () async {
      fake.report = {
        'reason': 'outOfMemory',
        'wasOutOfMemory': true,
        'memoryWarningCount': 3,
        'lastApplicationUsedMemory': 1450,
        'lastAppRemainingMemory': 12,
        'lastSeenAt': 1700000000000,
      };
      final report = await OutOfMemoryPlugin.getPreviousSessionReport();
      expect(report.reason, TerminationReason.outOfMemory);
      expect(report.wasOutOfMemory, isTrue);
      expect(report.memoryWarningCount, 3);
      expect(report.lastApplicationUsedMemory, 1450);
      expect(report.lastAppRemainingMemory, 12);
      expect(report.lastSeenAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    });

    test('every native reason maps to an enum value', () async {
      for (final name in ['firstLaunch', 'normalExit', 'appUpdate', 'osUpdate', 'debugger', 'background', 'outOfMemory']) {
        fake.report = {'reason': name};
        final report = await OutOfMemoryPlugin.getPreviousSessionReport();
        expect(report.reason.name, name);
        expect(report.wasOutOfMemory, name == 'outOfMemory');
      }
    });

    test('empty or unknown report is not an OOM', () async {
      var report = await OutOfMemoryPlugin.getPreviousSessionReport();
      expect(report.reason, TerminationReason.unknown);
      expect(report.wasOutOfMemory, isFalse);
      expect(report.lastSeenAt, isNull);

      fake.report = {'reason': 'somethingNew'};
      report = await OutOfMemoryPlugin.getPreviousSessionReport();
      expect(report.reason, TerminationReason.unknown);
    });

    test('markCleanExit reaches the platform', () async {
      await OutOfMemoryPlugin.markCleanExit();
      expect(fake.cleanExitMarked, isTrue);
    });

    test('onMemoryWarning forwards platform events', () async {
      expect(await OutOfMemoryPlugin.onMemoryWarning.first, 'Memory warning received');
    });
  });
}
