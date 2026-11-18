import 'package:flutter_test/flutter_test.dart';

import 'package:out_of_memory_plugin_example/main.dart';

void main() {
  testWidgets('shows previous session and memory sections', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Previous session'), findsOneWidget);
    expect(find.text('Memory now'), findsOneWidget);
  });
}
