// Basic Flutter widget test for AwiOS.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:awios/main.dart';

void main() {
  testWidgets('AwiOS app loads and shows home', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AwiOSApp(),
      ),
    );

    expect(find.text('AwiOS'), findsOneWidget);
  });
}
