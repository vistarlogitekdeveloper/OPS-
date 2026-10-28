import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/platform/download_helper.dart';
import '../../../core/theme/vistar.dart';
import '../../categories/data/category_model.dart';
import '../data/submission_models.dart';
import '../data/submissions_repository.dart';

String mimeForFileType(FileTypeCode t) => switch (t) {
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

IconData _iconFor(FileTypeCode t) => switch (t) {
      FileTypeCode.pdf => Icons.picture_as_pdf_outlined,
      FileTypeCode.ppt => Icons.slideshow_outlined,
      FileTypeCode.excel => Icons.table_chart_outlined,
      FileTypeCode.jpeg => Icons.image_outlined,
      FileTypeCode.word => Icons.description_outlined,
      FileTypeCode.unknown => Icons.insert_drive_file_outlined,
    };

String _kb(int bytes) => (bytes / 1024).toStringAsFixed(1);

/// The files attached to one point, each with its own download and — when
/// [onRemove] is given — remove button.
class ItemFilesList extends ConsumerStatefulWidget {
  const ItemFilesList({
    super.key,
    required this.item,
    this.onRemove,
  });

  final SubmissionItem item;

  /// Null hides the remove buttons (a reviewer, or a cycle with the approver).
  final Future<void> Function(ItemFile file)? onRemove;

  @override
  ConsumerState<ItemFilesList> createState() => _ItemFilesListState();
}

class _ItemFilesListState extends ConsumerState<ItemFilesList> {
  /// Files with a download or removal in flight, by index.
  final Set<int> _busy = {};

  Future<void> _run(int i, Future<void> Function() action) async {
    setState(() => _busy.add(i));
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy.remove(i));
    }
  }

  Future<void> _download(int i, ItemFile f) => _run(i, () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          final bytes =
              await ref.read(submissionsRepositoryProvider).downloadFile(widget.item, f);
          final where = await saveBytes(
            bytes: bytes,
            filename: f.fileName,
            mimeType: mimeForFileType(f.fileType),
          );
          messenger.showSnackBar(SnackBar(content: Text('Saved ${f.fileName} to $where.')));
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(ApiError.from(e).message)));
        }
      });

  Future<void> _remove(int i, ItemFile f) async {
    final messenger = ScaffoldMessenger.of(context);
    // Ask first; the spinner is for the request, not the question.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this file?'),
        content: Text(
          widget.item.files.length == 1
              ? '${f.fileName} is the only file here; the point will be empty again.'
              : '${f.fileName} will be removed from this point.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(i, () async {
      try {
        await widget.onRemove!(f);
        messenger.showSnackBar(SnackBar(content: Text('${f.fileName} removed.')));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(ApiError.from(e).message)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12);
    final files = widget.item.files;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < files.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(_iconFor(files[i].fileType), size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        files[i].fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        [
                          '${_kb(files[i].fileSize)} KB',
                          fileTypeLabel(files[i].fileType),
                          ?files[i].uploaderName,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    ],
                  ),
                ),
                if (_busy.contains(i))
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else ...[
                  IconButton(
                    tooltip: 'Download',
                    icon: const Icon(Icons.download_outlined),
                    onPressed: () => _download(i, files[i]),
                  ),
                  // A stand-in file (old backend) has no id to remove by.
                  if (widget.onRemove != null && files[i].id != null)
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.delete_outline, color: Vistar.bad),
                      onPressed: () => _remove(i, files[i]),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
