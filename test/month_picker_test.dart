import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opsapp/core/theme/app_theme.dart';
import 'package:opsapp/core/widgets/month_picker.dart';

/// Opens the picker and hands back whatever it returned.
Future<DateTime?> _open(
  WidgetTester tester, {
  required DateTime initial,
  DateTime? firstMonth,
  DateTime? lastMonth,
}) async {
  DateTime? result;
  var opened = false;

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              opened = true;
              result = await showMonthPicker(
                context: context,
                initial: initial,
                firstMonth: firstMonth,
                lastMonth: lastMonth,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(opened, isTrue);
  return result;
}

void main() {
  testWidgets('a month is one tap — no day grid to wade through',
      (tester) async {
    await _open(tester, initial: DateTime(2026, 5), lastMonth: DateTime(2026, 9));

    // All twelve months are offered at once.
    for (final m in ['Jan', 'Jun', 'Dec']) {
      expect(find.text(m), findsOneWidget);
    }
    // The year being browsed is shown, and no day-of-month is ever asked for.
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('15'), findsNothing);

    await tester.tap(find.text('Mar'));
    await tester.pumpAndSettle();
    // The dialog closes on that single tap.
    expect(find.text('Jan'), findsNothing);
  });

  testWidgets('the chosen month comes back as the first of that month',
      (tester) async {
    DateTime? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showMonthPicker(
                context: context,
                initial: DateTime(2026, 5),
                lastMonth: DateTime(2026, 9),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mar'));
    await tester.pumpAndSettle();

    expect(picked, DateTime(2026, 3));
  });

  testWidgets('a month past the cap cannot be chosen', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showMonthPicker(
                context: context,
                initial: DateTime(2026, 9),
                lastMonth: DateTime(2026, 9),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // December 2026 hasn't happened; tapping it does nothing and the dialog
    // stays open rather than silently accepting a future cycle.
    await tester.tap(find.text('Dec'));
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(find.text('Dec'), findsOneWidget);

    // The month at the cap is still selectable.
    await tester.tap(find.text('Sep'));
    await tester.pumpAndSettle();
    expect(picked, DateTime(2026, 9));
  });

  testWidgets('the year stepper stops at the range ends', (tester) async {
    await _open(
      tester,
      initial: DateTime(2026, 5),
      firstMonth: DateTime(2026, 1),
      lastMonth: DateTime(2026, 9),
    );

    // A single-year range leaves nowhere to step in either direction.
    final back = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );
    final forward = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(back.onPressed, isNull);
    expect(forward.onPressed, isNull);
  });

  testWidgets('an out-of-range initial month still opens on a valid page',
      (tester) async {
    // A stale stored selection (or a clock roll) must not open on a blank year.
    await _open(
      tester,
      initial: DateTime(2030, 4),
      firstMonth: DateTime(2024, 1),
      lastMonth: DateTime(2026, 9),
    );
    expect(find.text('2026'), findsOneWidget);
  });

  testWidgets('dismissing returns nothing', (tester) async {
    final result = await _open(
      tester,
      initial: DateTime(2026, 5),
      lastMonth: DateTime(2026, 9),
    );
    expect(result, isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Jan'), findsNothing);
  });
}
