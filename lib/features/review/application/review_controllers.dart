import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/page_result.dart';
import '../../auth/application/auth_controller.dart';
import '../../submissions/data/submission_models.dart';
import '../../submissions/data/submissions_repository.dart';

/// Work queue for reviewers. The server decides which statuses each role sees:
/// project manager -> awaiting them, regional manager -> approved by the
/// project manager, admin -> both stages, Ops Excellence -> approved and
/// awaiting marks. Further scoped by project assignment on the server.
class ReviewQueueController extends AsyncNotifier<PageResult<Submission>> {
  @override
  Future<PageResult<Submission>> build() {
    // Watched so the queue rebuilds when the signed-in role changes.
    ref.watch(authControllerProvider).user?.role;
    return ref.read(submissionsRepositoryProvider).queue();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    ref.invalidate(pendingReviewCountProvider);
    await future;
  }
}

final reviewQueueProvider =
    AsyncNotifierProvider<ReviewQueueController, PageResult<Submission>>(
        ReviewQueueController.new);

/// Single submission used by the detail view. Family by id so multiple detail
/// pages can coexist if needed.
final submissionDetailProvider =
    FutureProvider.autoDispose.family<Submission, String>((ref, id) async {
  return ref.watch(submissionsRepositoryProvider).getById(id);
});

/// Badge counter for the review section: SUBMITTED awaiting approval for
/// managers/admin, APPROVED-with-unscored-items for Ops Excellence. Invalidate
/// after any decision or score so the badge tracks the work.
final pendingReviewCountProvider =
    FutureProvider<PendingReviewCount>((ref) async {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) return PendingReviewCount.empty;
  return ref.read(submissionsRepositoryProvider).pendingCount();
});
