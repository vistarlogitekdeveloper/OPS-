import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/page_result.dart';
import '../../submissions/data/submission_models.dart';
import '../../submissions/data/submissions_repository.dart';

/// Queue of SUBMITTED submissions awaiting decision. Scoped by role on the
/// server side — manager sees their assigned projects only; admin/ops_excellence
/// see all.
class ReviewQueueController extends AsyncNotifier<PageResult<Submission>> {
  @override
  Future<PageResult<Submission>> build() {
    return ref.read(submissionsRepositoryProvider).queue();
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
