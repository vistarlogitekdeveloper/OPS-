import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/theme/vistar.dart';
import '../../../core/vistar/widgets.dart';
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
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => context.go('/submission/picker'));
      return const Scaffold(body: SizedBox.shrink());
    }

    final snap = ref.watch(cycleSnapshotProvider(sel));
    final controller = ref.read(cycleControllerProvider(sel));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Submission'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/submission/picker'),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: AsyncValueView(
                value: snap,
                onRetry: () => ref.invalidate(cycleSnapshotProvider(sel)),
                data: (data) => RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(cycleSnapshotProvider(sel)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _CycleHeader(
                        snap: data,
                        monthLabel: _formatMonth(sel.month),
                      ),
                      const SizedBox(height: 16),
                      const SectionTitle('Reports'),
                      _Tiles(
                        snapshot: data,
                        selection: sel,
                        controller: controller,
                      ),
                      const SizedBox(height: 16),
                      if (data.submission != null)
                        _SubmitButton(
                          submission: data.submission!,
                          controller: controller,
                        ),
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
    final maxMarks = snap.categories
        .where((c) => c.isActive)
        .fold(0, (s, c) => s + c.maxMarks);

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
                  project == null ? monthLabel : '${project.code} — $monthLabel',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              RibbonPill(
                label: submissionStatusLabel(status).toUpperCase(),
                kind: _statusPill(status),
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
            children: [
              _Metric(
                label: 'Score',
                value:
                    '${sub?.totalScore ?? 0}',
                suffix: '/ $maxMarks',
              ),
              const SizedBox(width: 32),
              _Metric(
                label: 'Files',
                value: '${sub?.items.length ?? 0}',
                suffix: '/ ${snap.categories.where((c) => c.isActive).length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  static PillKind _statusPill(SubmissionStatus s) {
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
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.suffix});
  final String label;
  final String value;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: theme.hintColor,
            fontSize: 10.5,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            RibbonText(
              value,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 26,
                letterSpacing: -0.4,
                height: 1,
              ),
            ),
            if (suffix != null) ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  suffix!,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Tiles extends ConsumerWidget {
  const _Tiles({
    required this.snapshot,
    required this.selection,
    required this.controller,
  });
  final CycleSnapshot snapshot;
  final CycleSelection selection;
  final CycleController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressByCat = ref.watch(uploadProgressProvider);
    final itemsByCat = {
      for (final i in snapshot.submission?.items ?? const <SubmissionItem>[])
        i.categoryId: i,
    };
    return Column(
      children: [
        for (final c in snapshot.categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CategoryTile(
              category: c,
              item: itemsByCat[c.id],
              progress: progressByCat[c.id],
              selection: selection,
              controller: controller,
            ),
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
                      category.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${category.maxMarks} marks · $allowed',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              RibbonPill(
                label: itemStatusLabel(status).toUpperCase(),
                kind: _itemPill(status),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasFile)
            Text(
              '${item!.fileName} · ${_kb(item!.fileSize)} KB',
              style: theme.textTheme.bodyMedium,
            )
          else
            Text(
              'No file uploaded yet',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          if (uploading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Vistar.pink),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${((progress ?? 0) * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (item?.reviewerComment != null)
                Expanded(
                  child: Text(
                    'Reviewer: ${item!.reviewerComment}',
                    style: const TextStyle(
                      color: Vistar.bad,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              RibbonButton(
                small: true,
                onPressed: uploading ? null : () => _pickAndUpload(context, ref),
                icon: Icons.upload_file,
                label: hasFile ? 'Replace' : 'Upload',
              ),
            ],
          ),
        ],
      ),
    );
  }

  static PillKind _itemPill(SubmissionItemStatus s) {
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

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final exts = category.allowedFileTypes
        .map((t) => switch (t) {
              FileTypeCode.pdf => ['pdf'],
              FileTypeCode.ppt => ['ppt', 'pptx'],
              FileTypeCode.excel => ['xls', 'xlsx'],
              FileTypeCode.jpeg => ['jpg', 'jpeg'],
              FileTypeCode.word => ['doc', 'docx'],
              FileTypeCode.unknown => <String>[],
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
    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not read the selected file.')));
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
      await controller.upload(
          categoryId: category.id, bytes: bytes, fileName: name);
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

class _SubmitButton extends StatefulWidget {
  const _SubmitButton({required this.submission, required this.controller});
  final Submission submission;
  final CycleController controller;

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
    return RibbonButton(
      onPressed: enabled ? _submit : null,
      icon: enabled ? Icons.send : Icons.hourglass_top_outlined,
      label: _busy
          ? 'Submitting…'
          : (enabled ? 'Submit for approval' : 'Awaiting review'),
      expand: true,
    );
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await widget.controller.submitForApproval(widget.submission.id);
      messenger.showSnackBar(
          const SnackBar(content: Text('Submitted for approval.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ApiError.from(e).message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
