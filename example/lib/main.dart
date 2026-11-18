import 'dart:io';

import 'package:flutter/material.dart';
import 'package:out_of_memory_plugin/out_of_memory_plugin.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  MemoryInformationResult? memoryInfo;
  PreviousSessionReport? previousSession;
  int memoryWarnings = 0;
  final List<List<int>> memoryHogger = [];

  @override
  void initState() {
    super.initState();

    // How did the previous run end? In a real app, log it to Crashlytics when wasOutOfMemory is
    // true and FirebaseCrashlytics.instance.didCrashOnPreviousExecution() is false.
    OutOfMemoryPlugin.getPreviousSessionReport().then((report) {
      debugPrint('Previous session: $report');
      setState(() => previousSession = report);
    });

    // Memory warnings are not OOMs; they are only shown here.
    OutOfMemoryPlugin.onMemoryWarning.listen((event) async {
      debugPrint('Memory warning event received: $event');
      setState(() => memoryWarnings++);
      await _getMemoryInfo();
    });

    _getMemoryInfo();
  }

  Future<void> _getMemoryInfo() async {
    final info = await OutOfMemoryPlugin.getMemoryInfo();
    setState(() => memoryInfo = info);
  }

  /// Allocates ~40 MB per tap. Keep tapping on a real device until iOS kills the app, then open it
  /// again from the home screen: the previous session should be reported as outOfMemory.
  Future<void> triggerOutOfMemory() async {
    memoryHogger.add(List.generate(5000000, (index) => index));
    await _getMemoryInfo();
  }

  @override
  Widget build(BuildContext context) {
    final report = previousSession;
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Out of memory plugin')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Previous session', style: Theme.of(context).textTheme.titleMedium),
            Text('reason: ${report?.reason.name ?? '...'}'),
            Text('wasOutOfMemory: ${report?.wasOutOfMemory ?? '...'}'),
            Text('memoryWarningCount: ${report?.memoryWarningCount ?? '...'}'),
            Text('lastApplicationUsedMemory: ${report?.lastApplicationUsedMemory ?? '...'} MB'),
            Text('lastAppRemainingMemory: ${report?.lastAppRemainingMemory ?? '...'} MB'),
            Text('lastSeenAt: ${report?.lastSeenAt ?? '-'}'),
            const Divider(height: 32),
            Text('Memory now', style: Theme.of(context).textTheme.titleMedium),
            Text('applicationUsedMemory: ${memoryInfo?.applicationUsedMemory} MB'),
            Text('availableMemory: ${memoryInfo?.availableMemory} MB'),
            Text('totalMemory: ${memoryInfo?.totalMemory} MB'),
            Text('appRemainingMemory: ${memoryInfo?.appRemainingMemory} MB'),
            Text('memory warnings this session: $memoryWarnings'),
            Text('allocated blocks: ${memoryHogger.length}'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _getMemoryInfo, child: const Text('Refresh memory info')),
            ElevatedButton(onPressed: triggerOutOfMemory, child: const Text('Memory+ (allocate)')),
            ElevatedButton(
              onPressed: () async {
                // dart:io exit() skips native exit handlers, so mark the exit first.
                await OutOfMemoryPlugin.markCleanExit();
                exit(0);
              },
              child: const Text('exit(0) → normalExit')),
          ],
        ),
      ),
    );
  }
}
