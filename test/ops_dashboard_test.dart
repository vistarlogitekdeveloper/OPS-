import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opsapp/core/theme/app_theme.dart';
import 'package:opsapp/features/dashboards/data/dashboards_repository.dart';
import 'package:opsapp/features/dashboards/data/ops_summary_models.dart';
import 'package:opsapp/features/dashboards/presentation/ops_dashboard.dart';
import 'package:opsapp/features/dashboards/presentation/widgets/ops_score_matrix.dart';

/// The ten report categories the monthly cycle is scored on, with their
/// ceilings — 96 marks in total.
const _categories = <(String, int)>[
  ('1) Monthly PPT', 20),
  ('2) SLA Report', 20),
  ('3) Daily cycle count report along with analysis', 10),
  ('4) Kaizens per Project(Cost, Process, Theme)', 10),
  ('5) Tracker-Customer Complaint register', 10),
  ('6) KRA Submission', 10),
  ('7) Deviation report (Process Deviation)', 5),
  ('8) Training records', 3),
  ('9) Monthly Audit report as per frequency', 3),
  ('10) Reward and recognition', 5),
];

/// A real July-2026 cycle: thirteen scored sites and eight that filed
/// nothing. Long site names, a zero, a missing mark and an absent site are all
/// represented, because those are the cases that break a grid.
const _scored = <(String, String, List<int?>)>[
  ('VST TILLERS TRACTORS LIMITED', 'Manager VST', [20, 18, 5, 5, 5, 10, 5, 3, 2, 5]),
  ('CNH INDUSTRIAL INDIA PVT LTD.', 'Rajesh Wagh', [10, 10, 10, 10, 8, 10, 5, 2, 2, 0]),
  (
    'KIRLOSKAR OIL ENGINES LIMITED (KOLHAPUR)',
    'Satish Shinde',
    [12, 20, 8, 10, 8, 0, 3, 2, 3, 0],
  ),
  (
    'BEKAERT INDUSTRIES PRIVATE LIMITED',
    'Govind Tapkir',
    [15, 20, 8, 5, 10, 10, 5, 3, 3, 5],
  ),
  (
    'SCHWING STETTER (INDIA) PVT. LTD.(BANGALORE)',
    'Manager SSBLR',
    [20, 0, 8, 10, 8, 10, 5, 3, 2, 0],
  ),
  ('MAXION WHEELS LIMITED', 'Manager Maxion', [10, 18, 10, 5, 8, 10, 3, 2, 1, 0]),
  ('KARL DUNGS PVT. LTD.', 'Vikram Desai', [15, 20, 5, 10, 10, 10, 5, 3, 3, 0]),
  (
    'ADEPT FLUIDYNE PVT. LTD (NANDED)',
    'Manager Adept',
    [15, 20, 10, 10, 10, 0, 5, 3, 3, 5],
  ),
  (
    'ENDURANCE TECHNOLOGIES LIMITED',
    'Pravin Wakchware',
    [10, 10, 5, 2, 8, 10, 5, 2, 2, 0],
  ),
  ('BOSH BIDADI ((BANGALORE)', 'Manager Bosch', [20, 20, 10, 0, 7, 10, 5, 3, 3, 0]),
  ('EATON RANJANGOAN', 'Dinesh Gawade', [20, 20, 10, 5, 7, 0, 5, 3, 2, 5]),
  // A filed cycle with one report still unmarked.
  ('KNORR BREMSE (PUNE)', 'Prakash Shivale', [15, 15, 3, 8, 10, 7, 5, null, 1, 0]),
  (
    'MOUNTAIN TRAIL FOODS PRIVATE LIMITED (PUNE)',
    'Milind Ingole',
    [15, 18, 10, 10, 7, 10, 5, 3, 1, 5],
  ),
];

const _absent = <String>[
  'BENI PVT LTD',
  'EATON INDIA INNOVATION CENTER LLP',
  'MOUNTAIN TRAIL FOODS PRIVATE LIMITED (BANGALORE)',
  'GRUPO ANTOLIN INDIA PRIVATE LIMITED',
  'SCHWING STETTER (INDIA) PVT. LTD. (PUNE)',
  'AUTOLIV INFLATORS INDIA PVT. LTD.',
  'KIRLOSKAR OIL ENGINES LIMITED (NASHIK)',
  'VISTAR HR DEPARTMENT',
];

/// Builds the July-2026 cycle payload the screen reads.
Map<String, dynamic> buildFixture() {
  final categories = [
    for (int i = 0; i < _categories.length; i++)
      {
        'id': 'cat$i',
        'name': _categories[i].$1,
        'maxMarks': _categories[i].$2,
        'displayOrder': i,
      },
  ];

  final rows = <Map<String, dynamic>>[];
  for (int r = 0; r < _scored.length; r++) {
    final (name, evaluator, marks) = _scored[r];
    rows.add({
      'projectId': 'p$r',
      'code': 'SITE-${r.toString().padLeft(3, '0')}',
      'name': name,
      'location': 'Pune',
      'submitted': true,
      'status': 'APPROVED',
      'evaluator': evaluator,
      'submittedBy': evaluator,
      'submittedAt': '2026-07-08T13:19:00.000Z',
      'totalScore': marks.whereType<int>().fold<int>(0, (a, b) => a + b),
      'uploadedCount': _categories.length,
      'scoredCount': marks.whereType<int>().length,
      'cells': [
        for (int i = 0; i < _categories.length; i++)
          {
            'categoryId': 'cat$i',
            'maxMarks': _categories[i].$2,
            'uploaded': true,
            'status': 'APPROVED',
            'awardedMarks': marks[i],
            'remark': 'Revised format not followed; needs review by the '
                'cluster manager before the next cycle.',
            'fileName': 'report.pdf',
            'uploadedAt': '2026-07-08T13:19:00.000Z',
          },
      ],
    });
  }
  for (int a = 0; a < _absent.length; a++) {
    rows.add({
      'projectId': 'a$a',
      'code': 'SITE-9$a',
      'name': _absent[a],
      'submitted': false,
      'status': null,
      'totalScore': null,
      'uploadedCount': 0,
      'scoredCount': 0,
      'cells': [
        for (int i = 0; i < _categories.length; i++)
          {
            'categoryId': 'cat$i',
            'maxMarks': _categories[i].$2,
            'uploaded': false,
            'status': null,
            'awardedMarks': null,
            'remark': null,
          },
      ],
    });
  }

  final totals = _scored
      .map((s) => s.$3.whereType<int>().fold<int>(0, (a, b) => a + b))
      .toList();

  return {
    'month': '2026-07',
    'maxTotal': _categories.fold<int>(0, (a, c) => a + c.$2),
    'categories': categories,
    'rows': rows,
    'stats': {
      'projectCount': rows.length,
      'submittedCount': _scored.length,
      'missingCount': _absent.length,
      'scoredCount': _scored.length,
      'awaitingMarksCount': 0,
      'total': {
        'average': totals.reduce((a, b) => a + b) / totals.length,
        'max': totals.reduce((a, b) => a > b ? a : b),
        'min': totals.reduce((a, b) => a < b ? a : b),
      },
      'categories': [
        for (int i = 0; i < _categories.length; i++)
          () {
            final marks = _scored
                .map((s) => s.$3[i])
                .whereType<int>()
                .toList();
            final avg = marks.reduce((a, b) => a + b) / marks.length;
            return {
              'categoryId': 'cat$i',
              'name': _categories[i].$1,
              'maxMarks': _categories[i].$2,
              'average': avg,
              'max': marks.reduce((a, b) => a > b ? a : b),
              'min': marks.reduce((a, b) => a < b ? a : b),
              'scoredCount': marks.length,
              'attainmentPercent': avg / _categories[i].$2 * 100,
              'skippedCount': 0,
            };
          }(),
      ],
    },
  };
}

Widget _harness(OpsSummary summary, {Brightness brightness = Brightness.dark}) {
  return ProviderScope(
    overrides: [
      opsSummaryProvider.overrideWith((ref, month) async => summary),
    ],
    child: MaterialApp(
      theme: brightness == Brightness.dark
          ? AppTheme.dark()
          : AppTheme.light(),
      home: const Scaffold(body: OpsExcellenceDashboard()),
    ),
  );
}

void main() {
  final summary = OpsSummary.fromJson(buildFixture());

  test('the payload parses into the shape the screen reads', () {
    expect(summary.categories, hasLength(10));
    expect(summary.maxTotal, 96);
    expect(summary.rows, hasLength(21));
    expect(summary.stats.total.max, 84);
    expect(summary.stats.total.min, 54);
    // A site that filed nothing keeps a null total rather than a zero, so it
    // can't be mistaken for a site that scored zero.
    expect(summary.notSubmitted, hasLength(8));
    expect(summary.notSubmitted.every((r) => r.totalScore == null), isTrue);
    // Ranked puts the best cycle first and the absent sites last.
    expect(summary.ranked.first.totalScore, 84);
    expect(summary.ranked.last.totalScore, isNull);
  });

  testWidgets('renders a full cycle on a desktop width', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(summary));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Evaluation summary'), findsOneWidget);
    // The spreadsheet footer the cycle is judged on.
    expect(find.text('Average'), findsOneWidget);
    expect(find.text('Maximum'), findsOneWidget);
    expect(find.text('Minimum'), findsOneWidget);
    expect(find.byType(OpsScoreMatrix), findsOneWidget);
  });

  testWidgets('renders on a phone width without overflowing', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(summary));
    await tester.pumpAndSettle();

    // A RenderFlex overflow surfaces here as a thrown exception.
    expect(tester.takeException(), isNull);
    expect(find.byType(OpsScoreMatrix), findsOneWidget);
  });

  testWidgets('the filed view swaps the grid to Y/N without losing rows',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(summary));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filed').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Submission review'), findsOneWidget);
    // Every absent site reads N across all ten reports.
    expect(find.text('N'), findsWidgets);
  });

  testWidgets('a site opens its remarks sheet', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(summary));
    await tester.pumpAndSettle();

    await tester.tap(find.text('KARL DUNGS PVT. LTD.'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Report-wise marks'), findsOneWidget);
    expect(find.textContaining('Evaluator: Vikram Desai'), findsOneWidget);
  });

  testWidgets('renders in light theme too', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(summary, brightness: Brightness.light));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
