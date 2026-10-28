// Several files per point: the model, the batch upload, the filer's tile
// (list, remove, locked) and the reviewer's read-only list.
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:opsapp/core/theme/app_theme.dart';
import 'package:opsapp/features/categories/data/category_model.dart';
import 'package:opsapp/features/submissions/application/cycle_controller.dart';
import 'package:opsapp/features/submissions/data/submission_models.dart';
import 'package:opsapp/features/submissions/data/submissions_repository.dart';
import 'package:opsapp/features/submissions/presentation/item_files_list.dart';
import 'package:opsapp/features/submissions/presentation/submission_screen.dart';

Map<String, dynamic> _file(String id, String name, {String? type = 'PDF'}) => {
      'id': id,
      'version': 1,
      'fileName': name,
      'fileType': type,
      'fileSize': 2048,
      'uploadedAt': '2026-10-01T10:00:00.000Z',
      'uploader': {'id': 'u1', 'name': 'Asha'},
    };

Map<String, dynamic> _item({List<Map<String, dynamic>>? files}) => {
      'id': 'item1',
      'submissionId': 's1',
      'categoryId': 'c1',
      'fileName': 'b.pdf',
      'fileType': 'PDF',
      'fileSize': 2048,
      'status': 'SUBMITTED',
      'awardedMarks': null,
      'reviewerComment': null,
      'uploadedAt': '2026-10-01T10:00:00.000Z',
      'files': ?files,
    };

Map<String, dynamic> _snapshot(String status) => {
      'submission': {
        'id': 's1',
        'projectId': 'p1',
        'month': '2026-09',
        'status': status,
        'totalScore': 0,
        'items': [
          _item(files: [_file('f1', 'a.pdf'), _file('f2', 'b.pdf')]),
        ],
        'approvals': const [],
      },
      'categories': [
        {'id': 'c1', 'name': 'Kaizen', 'maxMarks': 60, 'allowedFileTypes': ['PDF'], 'displayOrder': 1},
        {'id': 'c2', 'name': 'Safety', 'maxMarks': 40, 'allowedFileTypes': ['PDF'], 'displayOrder': 2},
      ],
    };

class _FakeRepo extends SubmissionsRepository {
  _FakeRepo({this.status = 'DRAFT'}) : super(Dio());
  String status;
  final uploads = <String>[];
  final appendFlags = <bool>[];
  final removed = <String>[];

  @override
  Future<CycleSnapshot> getCycle({required String projectId, required String month}) async =>
      CycleSnapshot.fromJson(_snapshot(status));

  @override
  Future<Submission> uploadFile({
    required String projectId,
    required String month,
    required String categoryId,
    required Uint8List bytes,
    required String fileName,
    void Function(int sent, int total)? onProgress,
    bool append = true,
  }) async {
    if (fileName == 'dup.pdf') {
      throw DioException(
        requestOptions: RequestOptions(path: '/submissions/upload'),
        response: Response(
          requestOptions: RequestOptions(path: '/submissions/upload'),
          statusCode: 409,
          data: {'error': {'message': '"dup.pdf" is already attached to "Kaizen".'}},
        ),
      );
    }
    onProgress?.call(bytes.length, bytes.length);
    uploads.add(fileName);
    appendFlags.add(append);
    return Submission.fromJson(_snapshot(status)['submission'] as Map<String, dynamic>);
  }

  @override
  Future<Submission> removeFile(String fileId) async {
    removed.add(fileId);
    return Submission.fromJson(_snapshot(status)['submission'] as Map<String, dynamic>);
  }
}

const _sel = CycleSelection(projectId: 'p1', month: '2026-09');

Widget _screen(_FakeRepo repo) {
  final router = GoRouter(initialLocation: '/submission', routes: [
    GoRoute(path: '/submission', builder: (_, _) => const SubmissionScreen()),
    GoRoute(path: '/submission/picker', builder: (_, _) => const Scaffold()),
    GoRoute(path: '/', builder: (_, _) => const Scaffold()),
  ]);
  return ProviderScope(
    overrides: [
      submissionsRepositoryProvider.overrideWithValue(repo),
      cycleSelectionProvider.overrideWith((ref) => _sel),
    ],
    child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
  );
}

void main() {
  group('model', () {
    test('a point carries all its files, oldest first', () {
      final item = SubmissionItem.fromJson(_item(files: [_file('f1', 'a.pdf'), _file('f2', 'b.xlsx', type: 'EXCEL')]));
      expect(item.files.map((f) => f.id), ['f1', 'f2']);
      expect(item.files[1].fileType, FileTypeCode.excel);
      expect(item.files[0].uploaderName, 'Asha');
    });

    test('an older backend (no files) gives one stand-in file from the item', () {
      final item = SubmissionItem.fromJson(_item());
      expect(item.files, hasLength(1));
      expect(item.files.single.id, isNull);
      expect(item.files.single.fileName, 'b.pdf');
    });

    test('an untyped history row takes its type from the file name', () {
      final f = ItemFile.fromJson(_file('f9', 'Deck.PPTX', type: null));
      expect(f.fileType, FileTypeCode.ppt);
    });
  });

  test('batch upload: appends each, keeps going past a refusal, clears progress', () async {
    final repo = _FakeRepo();
    final container = ProviderContainer(overrides: [submissionsRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    final seen = <UploadProgress>[];
    container.listen(uploadProgressProvider, (_, m) {
      final p = m['c1'];
      if (p != null) seen.add(p);
    });

    final failures = await container.read(cycleControllerProvider(_sel)).uploadFiles(
      categoryId: 'c1',
      files: [
        PendingUpload(bytes: Uint8List(10), fileName: 'one.pdf'),
        PendingUpload(bytes: Uint8List(10), fileName: 'dup.pdf'),
        PendingUpload(bytes: Uint8List(10), fileName: 'three.pdf'),
      ],
    );

    expect(repo.uploads, ['one.pdf', 'three.pdf']);
    expect(repo.appendFlags, everyElement(isTrue));
    expect(failures.map((f) => f.upload.fileName), ['dup.pdf']);
    expect(seen.map((p) => p.current).toSet(), {1, 2, 3});
    expect(seen.every((p) => p.total == 3), isTrue);
    expect(seen.last.fraction, 1.0);
    expect(container.read(uploadProgressProvider), isEmpty);
  });

  testWidgets('filer: lists every file, removes one after confirming', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo();
    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    expect(find.text('a.pdf'), findsOneWidget);
    expect(find.text('b.pdf'), findsOneWidget);
    expect(find.text('Add files'), findsOneWidget); // Kaizen has files
    expect(find.text('Upload files'), findsOneWidget); // Safety has none
    expect(find.text('POINTS FILED'), findsOneWidget); // _Metric upper-cases its label
    expect(find.byTooltip('Remove'), findsNWidgets(2));
    expect(find.byTooltip('Download'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();
    expect(find.text('Remove this file?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(repo.removed, ['f1']);
    expect(find.text('a.pdf removed.'), findsOneWidget);
  });

  testWidgets('filer: no remove buttons while the cycle is with the approver', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_screen(_FakeRepo(status: 'SUBMITTED')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove'), findsNothing);
    expect(find.byTooltip('Download'), findsNWidgets(2));
    expect(find.text('Locked'), findsNWidgets(2));
  });

  for (final width in const [320.0, 375.0]) {
    testWidgets('filer tile fits a ${width.toInt()}px phone with long file names', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final errors = <FlutterErrorDetails>[];
      final prev = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = prev);
      final item = SubmissionItem.fromJson(_item(files: [
        _file('f1', 'Kaizen-evidence-for-September-2026-plant-floor-photos-final-v3.pdf'),
      ]));
      await tester.pumpWidget(ProviderScope(
        overrides: [submissionsRepositoryProvider.overrideWithValue(_FakeRepo())],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: ItemFilesList(item: item, onRemove: (_) async {})),
        ),
      ));
      await tester.pumpAndSettle();
      FlutterError.onError = prev;
      expect(errors.map((e) => e.exceptionAsString()), isEmpty);
    });
  }

  testWidgets('reviewer: read-only list, one download per file', (tester) async {
    final item = SubmissionItem.fromJson(_item(files: [_file('f1', 'a.pdf'), _file('f2', 'b.pdf'), _file('f3', 'c.pdf')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [submissionsRepositoryProvider.overrideWithValue(_FakeRepo())],
      child: MaterialApp(theme: AppTheme.dark(), home: Scaffold(body: ItemFilesList(item: item))),
    ));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Download'), findsNWidgets(3));
    expect(find.byTooltip('Remove'), findsNothing);
  });
}
