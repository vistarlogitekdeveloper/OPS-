import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../categories/data/category_model.dart';
import '../application/cycle_controller.dart';
import '../data/submission_models.dart';

class SubmissionScreen extends ConsumerWidget {
  const SubmissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(cycleSelectionProvider);
    if (sel == null) {
      // Direct nav without a selection — bounce to picker.
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/submission/picker'));
      return const Scaffold(body: SizedBox.shrink());
    }

    final theme = Theme.of(context);
    final snap = ref.watch(cycleSnapshotProvider(sel));
    final controller = ref.read(cycleControllerProvider(sel));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submission'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/submission/picker'),
        ),
      ),
      body: AsyncValueView(
        value: snap,
        onRetry: () => ref.invalidate(cycleSnapshotProvider(sel)),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(cycleSnapshotProvider(sel)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CycleHeader(snap: data, monthLabel: _formatMonth(sel.month)),
              const SizedBox(height: 16),
              _Tiles(snapshot: data, selection: sel, controller: controller),
              const SizedBox(height: 16),
              if (data.submission != null)
                _SubmitButton(submission: data.submission!, controller: controller, theme: theme),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatMonth(String yyyymm) {
    try {
      final parts = yyyymm.split('-');
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat.yMMMM().format(dt);
    } catch (_) {
      return yyyymm;
    }
  }
}

class _CycleHeader extends StatelessWidget {
  const _CycleHeader({required this.snap, required this.monthLabel});
  final CycleSnapshot snap;
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = snap.submission;
    final project = sub?.project;
    final status = sub?.status ?? SubmissionStatus.draft;

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
                    project == null ? monthLabel : '${project.code} — $monthLabel',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            if (project != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(project.name, style: theme.textTheme.bodyMedium),
              ),
            const SizedBox(height: 8),
            Text(
              sub == null
                  ? 'Draft — no files uploaded yet.'
                  : 'Score so far: ${sub.totalScore} / ${_maxMarks(snap)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  int _maxMarks(CycleSnapshot snap) =>
      snap.categories.where((c) => c.isActive).fold(0, (s, c) => s + c.maxMarks);
}

class _Tiles extends ConsumerWidget {
  const _Tiles({required this.snapshot, required this.selection, required this.controller});
  final CycleSnapshot snapshot;
  final CycleSelection selection;
  final CycleController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressByCat = ref.watch(uploadProgressProvider);
    final itemsByCat = {
      for (final i in snapshot.submission?.items ?? const <SubmissionItem>[]) i.categoryId: i,
    };
    return Column(
      children: [
        for (final c in snapshot.categories)
          _CategoryTile(
            category: c,
            item: itemsByCat[c.id],
            progress: progressByCat[c.id],
            selection: selection,
            controller: controller,
          ),
      ],
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({
    required this.category,
    required this.item,
    required this.progress,
    required this.selection,
    required this.controller,
  });

  final ReportCategory category;
  final SubmissionItem? item;
  final double? progress;
  final CycleSelection selection;
  final CycleController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final uploading = progress != null;
    final allowed = category.allowedFileTypes.map(fileTypeLabel).join(', ');
    final status = item?.status ?? SubmissionItemStatus.pending;
    final hasFile = item != null;

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
                      Text(category.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${category.maxMarks} marks · $allowed',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _ItemStatusChip(status: status),
              ],
            ),
            const SizedBox(height: 8),
            if (hasFile)
              Text(
                '${item!.fileName} · ${_kb(item!.fileSize)} KB',
                style: theme.textTheme.bodyMedium,
              )
            else
              Text(
                'No file uploaded yet',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            if (uploading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${((progress ?? 0) * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.bodySmall),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (item?.reviewerComment != null)
                  Expanded(
                    child: Text(
                      'Reviewer: ${item!.reviewerComment}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: uploading ? null : () => _pickAndUpload(context, ref),
                  icon: const Icon(Icons.upload_file),
                  label: Text(hasFile ? 'Replace' : 'Upload'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final exts = category.allowedFileTypes
        .map((t) => switch (t) {
              FileTypeCode.pdf => ['pdf'],
              FileTypeCode.ppt => ['ppt', 'pptx'],
              FileTypeCode.excel => ['xls', 'xlsx'],
              FileTypeCode.jpeg => ['jpg', 'jpeg'],
            })
        .expand((e) => e)
        .toList();

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: exts,
        withData: true,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('File picker failed: $e')));
      return;
    }
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not read the selected file.')));
      return;
    }

    await _doUpload(messenger, bytes, file.name);
  }

  Future<void> _doUpload(
    ScaffoldMessengerState messenger,
    Uint8List bytes,
    String name,
  ) async {
    try {
      await controller.upload(categoryId: category.id, bytes: bytes, fileName: name);
      messenger.showSnackBar(SnackBar(content: Text('$name uploaded.')));
    } catch (e) {
      final err = ApiError.from(e);
      messenger.showSnackBar(
        SnackBar(
          content: Text(err.message),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _doUpload(messenger, bytes, name),
          ),
        ),
      );
    }
  }

  String _kb(int bytes) => (bytes / 1024).toStringAsFixed(1);
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

class _SubmitButton extends StatefulWidget {
  const _SubmitButton({required this.submission, required this.controller, required this.theme});
  final Submission submission;
  final CycleController controller;
  final ThemeData theme;

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final enabled = !_busy &&
        (widget.submission.status == SubmissionStatus.draft ||
            widget.submission.status == SubmissionStatus.rejected);
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: enabled ? _submit : null,
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.send),
        label: Text(enabled ? 'Submit for approval' : 'Awaiting review'),
      ),
    );
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await widget.controller.submitForApproval(widget.submission.id);
      messenger.showSnackBar(const SnackBar(content: Text('Submitted for approval.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ApiError.from(e).message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
