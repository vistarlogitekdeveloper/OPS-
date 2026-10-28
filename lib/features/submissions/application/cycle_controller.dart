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

/// Progress of one point's upload batch: file [current] of [total], and the
/// whole batch's share sent (0.0..1.0).
class UploadProgress {
  const UploadProgress({required this.current, required this.total, required this.fraction});
  final int current;
  final int total;
  final double fraction;
}

/// Per-tile upload progress, keyed by categoryId.
final uploadProgressProvider =
    StateProvider<Map<String, UploadProgress>>((ref) => const <String, UploadProgress>{});

/// A picked file waiting to go up.
class PendingUpload {
  const PendingUpload({required this.bytes, required this.fileName});
  final Uint8List bytes;
  final String fileName;
}

/// A file of a batch the server refused or that never arrived.
class UploadFailure {
  const UploadFailure({required this.upload, required this.error});
  final PendingUpload upload;
  final Object error;
}

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

  /// Adds [files] to a point, one request each, in order. A refused file does
  /// not stop the rest; the ones that failed come back for the caller to show.
  Future<List<UploadFailure>> uploadFiles({
    required String categoryId,
    required List<PendingUpload> files,
  }) async {
    final progress = ref.read(uploadProgressProvider.notifier);
    final failures = <UploadFailure>[];
    void report(int index, double filePart) => progress.update((m) => {
          ...m,
          categoryId: UploadProgress(
            current: index + 1,
            total: files.length,
            fraction: ((index + filePart) / files.length).clamp(0.0, 1.0),
          ),
        });
    try {
      for (var i = 0; i < files.length; i++) {
        report(i, 0);
        try {
          await ref.read(submissionsRepositoryProvider).uploadFile(
                projectId: selection.projectId,
                month: selection.month,
                categoryId: categoryId,
                bytes: files[i].bytes,
                fileName: files[i].fileName,
                onProgress: (sent, total) {
                  if (total > 0) report(i, (sent / total).clamp(0.0, 1.0));
                },
              );
        } catch (e) {
          failures.add(UploadFailure(upload: files[i], error: e));
        }
      }
    } finally {
      progress.update((m) => {...m}..remove(categoryId));
    }
    ref.invalidate(cycleSnapshotProvider(selection));
    return failures;
  }

  Future<void> removeFile(String fileId) async {
    await ref.read(submissionsRepositoryProvider).removeFile(fileId);
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
