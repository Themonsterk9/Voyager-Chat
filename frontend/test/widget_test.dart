import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('Voyager Chat starts successfully', (tester) async {
    await tester.pumpWidget(const VoyagerChatApp(testMode: true));

    await tester.pump();

    expect(find.text('Voyager Chat'), findsOneWidget);
  });
}
