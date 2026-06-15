import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/platform/download_helper.dart';
import '../../../core/theme/vistar.dart';
import '../../../core/vistar/widgets.dart';
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Review'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/review'),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: AsyncValueView(
                value: async,
                onRetry: () =>
                    ref.invalidate(submissionDetailProvider(submissionId)),
                data: (sub) => RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(submissionDetailProvider(submissionId)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _Header(submission: sub),
                      const SizedBox(height: 16),
                      const SectionTitle('Items'),
                      for (final item in sub.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ItemCard(
                            submission: sub,
                            item: item,
                            canScore: (role == UserRole.opsExcellence ||
                                    role == UserRole.admin) &&
                                sub.status == SubmissionStatus.approved,
                          ),
                        ),
                      if (role == UserRole.manager ||
                          role == UserRole.admin) ...[
                        const SizedBox(height: 8),
                        _DecisionActions(submission: sub),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

PillKind _statusPill(SubmissionStatus s) {
  switch (s) {
    case SubmissionStatus.draft:
      return PillKind.neutral;
    case SubmissionStatus.submitted:
      return PillKind.info;
    case SubmissionStatus.approved:
      return PillKind.ok;
    case SubmissionStatus.rejected:
      return PillKind.bad;
    case SubmissionStatus.unknown:
      return PillKind.neutral;
  }
}

PillKind _itemPill(SubmissionItemStatus s) {
  switch (s) {
    case SubmissionItemStatus.pending:
      return PillKind.neutral;
    case SubmissionItemStatus.submitted:
      return PillKind.info;
    case SubmissionItemStatus.approved:
      return PillKind.ok;
    case SubmissionItemStatus.rejected:
      return PillKind.bad;
    case SubmissionItemStatus.unknown:
      return PillKind.neutral;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.submission});
  final Submission submission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final project = submission.project;
    return VistarCard(
      cornerS: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  project == null
                      ? submission.month
                      : '${project.code} — ${submission.month}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              RibbonPill(
                label: submissionStatusLabel(submission.status).toUpperCase(),
                kind: _statusPill(submission.status),
              ),
            ],
          ),
          if (project != null) ...[
            const SizedBox(height: 4),
            Text(
              project.name,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'TOTAL SCORE',
                style: TextStyle(
                  color: theme.hintColor,
                  fontSize: 10.5,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              RibbonText(
                '${submission.totalScore}',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  letterSpacing: -0.4,
                  height: 1,
                ),
              ),
            ],
          ),
          if (submission.comments != null && submission.comments!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(Vistar.rSm),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Text(
                'Reviewer note: ${submission.comments}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
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
    final hasMarks = item.awardedMarks != null;
    final maxMarks = cat?.maxMarks;

    return VistarCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat?.name ?? 'Category',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.fileName} · ${_kb(item.fileSize)} KB · ${fileTypeLabel(item.fileType)}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              RibbonPill(
                label: itemStatusLabel(item.status).toUpperCase(),
                kind: _itemPill(item.status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hasMarks ? 'AWARDED' : 'NOT SCORED',
                style: TextStyle(
                  color: theme.hintColor,
                  fontSize: 10.5,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              if (hasMarks) ...[
                RibbonText(
                  '${item.awardedMarks}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.4,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '/ ${maxMarks ?? '?'}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'max ${maxMarks ?? '?'}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _downloading ? null : _download,
                icon: _downloading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: const Text('Download'),
              ),
              if (widget.canScore) ...[
                const Spacer(),
                RibbonButton(
                  small: true,
                  onPressed: _openScore,
                  icon: Icons.scoreboard_outlined,
                  label: hasMarks ? 'Edit score' : 'Score',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _download() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _downloading = true);
    try {
      final bytes = await ref
          .read(submissionsRepositoryProvider)
          .downloadItem(widget.item.id);
      final where = await saveBytes(
        bytes: bytes,
        filename: widget.item.fileName,
        mimeType: _mimeFor(widget.item.fileType),
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Saved ${widget.item.fileName} to $where.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ApiError.from(e).message)));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  static String _mimeFor(FileTypeCode t) => switch (t) {
        FileTypeCode.pdf => 'application/pdf',
        FileTypeCode.ppt =>
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        FileTypeCode.excel =>
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        FileTypeCode.jpeg => 'image/jpeg',
        FileTypeCode.word =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        FileTypeCode.unknown => 'application/octet-stream',
      };

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
    final theme = Theme.of(context);
    final canDecide = submission.status == SubmissionStatus.submitted;
    return VistarCard(
      cornerS: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Decision'),
          Text(
            canDecide
                ? 'Approve or reject this submission. All items follow the submission state.'
                : 'Already ${submissionStatusLabel(submission.status).toLowerCase()}.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      !canDecide ? null : () => _decide(context, ref, false),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: canDecide ? Vistar.bad : null,
                    side: BorderSide(
                      color: canDecide
                          ? Vistar.bad.withValues(alpha: 0.6)
                          : theme.colorScheme.outline,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RibbonButton(
                  onPressed:
                      !canDecide ? null : () => _decide(context, ref, true),
                  icon: Icons.check,
                  label: 'Approve',
                  expand: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _decide(
      BuildContext context, WidgetRef ref, bool approve) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => DecisionDialog(submission: submission, approve: approve),
    );
    if (updated == true) {
      ref.invalidate(submissionDetailProvider(submission.id));
      ref.invalidate(reviewQueueProvider);
    }
  }
}
