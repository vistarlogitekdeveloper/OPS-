import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/submission_models.dart';
import '../data/submissions_repository.dart';

class CycleSelection {
  const CycleSelection({required this.projectId, required this.month});
  final String projectId;
  final String month;

  @override
  bool operator ==(Object other) =>
      other is CycleSelection && other.projectId == projectId && other.month == month;

  @override
  int get hashCode => Object.hash(projectId, month);
}

/// Tracks the active project + month for the site-user submission flow.
final cycleSelectionProvider = StateProvider<CycleSelection?>((ref) => null);

/// Per-tile upload progress, keyed by categoryId. 0.0..1.0.
final uploadProgressProvider =
    StateProvider<Map<String, double>>((ref) => const <String, double>{});

/// Loads the cycle's submission + active categories.
final cycleSnapshotProvider =
    FutureProvider.family<CycleSnapshot, CycleSelection>((ref, sel) async {
  return ref.watch(submissionsRepositoryProvider).getCycle(
        projectId: sel.projectId,
        month: sel.month,
      );
});

class CycleController {
  CycleController(this.ref, this.selection);
  final Ref ref;
  final CycleSelection selection;

  Future<void> upload({
    required String categoryId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final progress = ref.read(uploadProgressProvider.notifier);
    progress.update((m) => {...m, categoryId: 0});
    try {
      await ref.read(submissionsRepositoryProvider).uploadFile(
            projectId: selection.projectId,
            month: selection.month,
            categoryId: categoryId,
            bytes: bytes,
            fileName: fileName,
            onProgress: (sent, total) {
              if (total <= 0) return;
              final pct = (sent / total).clamp(0.0, 1.0);
              progress.update((m) => {...m, categoryId: pct});
            },
          );
    } finally {
      progress.update((m) => {...m}..remove(categoryId));
    }
    ref.invalidate(cycleSnapshotProvider(selection));
  }

  Future<void> submitForApproval(String submissionId) async {
    await ref.read(submissionsRepositoryProvider).submitForApproval(submissionId);
    ref.invalidate(cycleSnapshotProvider(selection));
  }
}

final cycleControllerProvider =
    Provider.family<CycleController, CycleSelection>((ref, sel) {
  return CycleController(ref, sel);
});
