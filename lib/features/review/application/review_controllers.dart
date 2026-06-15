import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/page_result.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_models.dart';
import '../../submissions/data/submission_models.dart';
import '../../submissions/data/submissions_repository.dart';

/// Work queue for reviewers. Managers/admins act on SUBMITTED submissions
/// (approve/reject); Ops Excellence allocates marks on APPROVED ones, so they
/// get the APPROVED list instead. Further scoped by assignment on the server.
class ReviewQueueController extends AsyncNotifier<PageResult<Submission>> {
  @override
  Future<PageResult<Submission>> build() {
    final role = ref.watch(authControllerProvider).user?.role;
    final repo = ref.read(submissionsRepositoryProvider);
    if (role == UserRole.opsExcellence) {
      return repo.list(status: 'APPROVED');
    }
    return repo.queue();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
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
