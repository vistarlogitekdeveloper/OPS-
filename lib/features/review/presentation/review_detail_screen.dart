import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_models.dart';
import '../../categories/data/category_model.dart';
import '../../submissions/data/submission_models.dart';
import '../../submissions/data/submissions_repository.dart';
import '../application/review_controllers.dart';
import 'decision_dialog.dart';
import 'score_item_dialog.dart';

class ReviewDetailScreen extends ConsumerWidget {
  const ReviewDetailScreen({super.key, required this.submissionId});
  final String submissionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(submissionDetailProvider(submissionId));
    final role = ref.watch(authControllerProvider).user?.role;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/review'),
        ),
      ),
      body: AsyncValueView(
        value: async,
        onRetry: () => ref.invalidate(submissionDetailProvider(submissionId)),
        data: (sub) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(submissionDetailProvider(submissionId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(submission: sub),
              const SizedBox(height: 16),
              for (final item in sub.items)
                _ItemCard(
                  submission: sub,
                  item: item,
                  canScore: (role == UserRole.opsExcellence || role == UserRole.admin) &&
                      sub.status == SubmissionStatus.approved,
                ),
              if (role == UserRole.manager || role == UserRole.admin) ...[
                const SizedBox(height: 16),
                _DecisionActions(submission: sub),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.submission});
  final Submission submission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final project = submission.project;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project == null ? submission.month : '${project.code} — ${submission.month}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _StatusChip(status: submission.status),
              ],
            ),
            if (project != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(project.name, style: theme.textTheme.bodyMedium),
              ),
            const SizedBox(height: 8),
            Text(
              'Score: ${submission.totalScore}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (submission.comments != null && submission.comments!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Reviewer note: ${submission.comments}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends ConsumerStatefulWidget {
  const _ItemCard({
    required this.submission,
    required this.item,
    required this.canScore,
  });
  final Submission submission;
  final SubmissionItem item;
  final bool canScore;

  @override
  ConsumerState<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends ConsumerState<_ItemCard> {
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final cat = item.category;
    final marksLine = item.awardedMarks == null
        ? 'No marks yet (max ${cat?.maxMarks ?? '?'})'
        : 'Awarded ${item.awardedMarks} / ${cat?.maxMarks ?? '?'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat?.name ?? 'Category', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${item.fileName} · ${_kb(item.fileSize)} KB · ${fileTypeLabel(item.fileType)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _ItemStatusChip(status: item.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(marksLine, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _downloading ? null : _download,
                  icon: _downloading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_outlined),
                  label: const Text('Download'),
                ),
                if (widget.canScore) ...[
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: _openScore,
                    icon: const Icon(Icons.scoreboard_outlined),
                    label: Text(item.awardedMarks == null ? 'Score' : 'Edit score'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _download() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _downloading = true);
    try {
      // Pull the bytes — the user can save them later via a future Phase 8
      // exporter. For now we just confirm the download round-trip works.
      final bytes = await ref
          .read(submissionsRepositoryProvider)
          .downloadItem(widget.item.id);
      messenger.showSnackBar(
        SnackBar(content: Text('Downloaded ${bytes.length} bytes from ${widget.item.fileName}.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ApiError.from(e).message)));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _openScore() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => ScoreItemDialog(
        submissionId: widget.submission.id,
        item: widget.item,
      ),
    );
    if (updated == true) {
      ref.invalidate(submissionDetailProvider(widget.submission.id));
    }
  }

  String _kb(int bytes) => (bytes / 1024).toStringAsFixed(1);
}

class _DecisionActions extends ConsumerWidget {
  const _DecisionActions({required this.submission});
  final Submission submission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canDecide = submission.status == SubmissionStatus.submitted;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Decision', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              canDecide
                  ? 'Approve or reject this submission. All items follow the submission state.'
                  : 'Already ${submissionStatusLabel(submission.status).toLowerCase()}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: !canDecide ? null : () => _decide(context, ref, false),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: !canDecide ? null : () => _decide(context, ref, true),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(BuildContext context, WidgetRef ref, bool approve) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => DecisionDialog(submission: submission, approve: approve),
    );
    if (updated == true) {
      ref.invalidate(submissionDetailProvider(submission.id));
      // Also refresh the queue list since the row should disappear.
      ref.invalidate(reviewQueueProvider);
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final SubmissionStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      SubmissionStatus.draft => (scheme.surfaceContainerHigh, scheme.onSurface),
      SubmissionStatus.submitted => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      SubmissionStatus.approved => (scheme.primaryContainer, scheme.onPrimaryContainer),
      SubmissionStatus.rejected => (scheme.errorContainer, scheme.onErrorContainer),
      SubmissionStatus.unknown => (scheme.surfaceContainerHigh, scheme.onSurface),
    };
    return Chip(
      label: Text(submissionStatusLabel(status)),
      backgroundColor: bg,
      labelStyle: TextStyle(color: fg),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ItemStatusChip extends StatelessWidget {
  const _ItemStatusChip({required this.status});
  final SubmissionItemStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      SubmissionItemStatus.pending => (scheme.surfaceContainerHigh, scheme.onSurface),
      SubmissionItemStatus.submitted => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      SubmissionItemStatus.approved => (scheme.primaryContainer, scheme.onPrimaryContainer),
      SubmissionItemStatus.rejected => (scheme.errorContainer, scheme.onErrorContainer),
      SubmissionItemStatus.unknown => (scheme.surfaceContainerHigh, scheme.onSurface),
    };
    return Chip(
      label: Text(itemStatusLabel(status)),
      backgroundColor: bg,
      labelStyle: TextStyle(color: fg),
      visualDensity: VisualDensity.compact,
    );
  }
}
