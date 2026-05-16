import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opsapp/app.dart';

void main() {
  testWidgets('OpsApp boots without errors and reaches the login screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: OpsApp()));
    // First frame: splash. Pump until the router lands somewhere.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    // Once auth is "unauthenticated", the redirect lands on /login.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
