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
  @override
  void initState() {
    super.initState();

    // Native tarafındaki memory warning eventlerini dinle
    OutOfMemoryPlugin.onMemoryWarning.listen((event) async {
      print("Memory warning event received: $event");
      await _getMemoryInfo();
    });
  }

  MemoryInformationResult? memoryInfo;

  Future<void> _getMemoryInfo() async {
    var info = await OutOfMemoryPlugin.getMemoryInfo();
    setState(() {
      memoryInfo = info;
    });
  }

  List<List<int>> memoryHogger = [];

  Future<void> triggerOutOfMemory() async {
    memoryHogger.add(List.generate(5000000, (index) => index));
    print('List size: ${memoryHogger.length}');
    await _getMemoryInfo();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Memory Warning Example')),
        body: Column(
          children: [
            Text('Memory Total: ${memoryInfo?.totalMemory}'),
            Text('Memory applicationUsedMemory: ${memoryInfo?.applicationUsedMemory}'),
            Text('Memory availableMemory: ${memoryInfo?.availableMemory}'),
            ElevatedButton(onPressed: _getMemoryInfo, child: Text("Memory Bilgilerini Yenile")),
            ElevatedButton(onPressed: triggerOutOfMemory, child: Text("Memory+")),
          ],
        ),
      ),
    );
  }
}
