// import 'package:flutter_test/flutter_test.dart';
// import 'package:out_of_memory_plugin/out_of_memory_plugin.dart';
// import 'package:out_of_memory_plugin/out_of_memory_plugin_platform_interface.dart';
// import 'package:out_of_memory_plugin/out_of_memory_plugin_method_channel.dart';
// import 'package:plugin_platform_interface/plugin_platform_interface.dart';
//
// class MockOutOfMemoryPluginPlatform
//     with MockPlatformInterfaceMixin
//     implements OutOfMemoryPluginPlatform {
//
//   @override
//   Future<String?> getPlatformVersion() => Future.value('42');
// }
//
// void main() {
//   final OutOfMemoryPluginPlatform initialPlatform = OutOfMemoryPluginPlatform.instance;
//
//   test('$MethodChannelOutOfMemoryPlugin is the default instance', () {
//     expect(initialPlatform, isInstanceOf<MethodChannelOutOfMemoryPlugin>());
//   });
//
//   test('getPlatformVersion', () async {
//     OutOfMemoryPlugin outOfMemoryPlugin = OutOfMemoryPlugin();
//     MockOutOfMemoryPluginPlatform fakePlatform = MockOutOfMemoryPluginPlatform();
//     OutOfMemoryPluginPlatform.instance = fakePlatform;
//
//     expect(await outOfMemoryPlugin.getPlatformVersion(), '42');
//   });
// }
