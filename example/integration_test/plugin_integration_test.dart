// Runs on a real iOS device or simulator: `flutter test integration_test`.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:out_of_memory_plugin/out_of_memory_plugin.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('getMemoryInfo returns real values', (WidgetTester tester) async {
    final info = await OutOfMemoryPlugin.getMemoryInfo();
    expect(info.applicationUsedMemory, greaterThan(0));
    expect(info.totalMemory, greaterThan(0));
    expect(info.availableMemory, greaterThan(0));
    expect(info.availableMemory, lessThan(info.totalMemory));
    expect(info.appRemainingMemory, greaterThanOrEqualTo(0));
  });

  testWidgets('getPreviousSessionReport returns a known reason', (WidgetTester tester) async {
    final report = await OutOfMemoryPlugin.getPreviousSessionReport();
    expect(report.reason, isNot(TerminationReason.unknown));
  });
}
