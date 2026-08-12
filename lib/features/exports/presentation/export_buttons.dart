import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/platform/download_helper.dart';
import '../../../core/vistar/widgets.dart';
import '../application/export_location_controller.dart';
import '../data/exports_repository.dart';

/// PDF/Excel export actions for a month, optionally scoped to a single site.
///
/// When [projectId] is given the report covers just that site and the file is
/// named after it (e.g. `SITE-001_Chennai-Hub_2026-08.xlsx`); otherwise it
/// spans every site the signed-in user can see. On desktop and Android the
/// destination folder is user-selectable and remembered between runs.
class ExportButtons extends ConsumerStatefulWidget {
  const ExportButtons({super.key, required this.month, this.projectId});
  final String month;
  final String? projectId;

  @override
  ConsumerState<ExportButtons> createState() => _ExportButtonsState();
}

class _ExportButtonsState extends ConsumerState<ExportButtons> {
  bool _busyPdf = false;
  bool _busyXlsx = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dir = ref.watch(exportLocationProvider).valueOrNull;
    final busy = _busyPdf || _busyXlsx;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          children: [
            RibbonButton(
              small: true,
              onPressed: busy ? null : () => _doExport(pdf: true),
              icon: Icons.picture_as_pdf_outlined,
              label: _busyPdf ? 'Saving PDF…' : 'Export PDF',
            ),
            RibbonButton(
              small: true,
              onPressed: busy ? null : () => _doExport(pdf: false),
              icon: Icons.table_chart_outlined,
              label: _busyXlsx ? 'Saving Excel…' : 'Export Excel',
            ),
          ],
        ),
        if (supportsLocationPicker) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  dir == null ? 'Saves to Downloads' : 'Saves to $dir',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: busy ? null : _chooseLocation,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(dir == null ? 'Change…' : 'Change'),
              ),
              if (dir != null)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => ref.read(exportLocationProvider.notifier).clear(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Reset'),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _chooseLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ref.read(exportLocationProvider.notifier).choose();
    if (!mounted) return;
    if (picked == null) return; // cancelled — keep the previous choice
    messenger.showSnackBar(
      SnackBar(content: Text('Exports will be saved to $picked.')),
    );
  }

  Future<void> _doExport({required bool pdf}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      if (pdf) {
        _busyPdf = true;
      } else {
        _busyXlsx = true;
      }
    });
    try {
      final repo = ref.read(exportsRepositoryProvider);
      final file = pdf
          ? await repo.monthlyPdf(month: widget.month, projectId: widget.projectId)
          : await repo.monthlyXlsx(month: widget.month, projectId: widget.projectId);
      final mime = pdf
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      final where = await saveBytes(
        bytes: file.bytes,
        filename: file.filename,
        mimeType: mime,
        directory: ref.read(exportLocationProvider).valueOrNull,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Saved ${file.filename} to $where.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ApiError.from(e).message)));
    } finally {
      if (mounted) {
        setState(() {
          if (pdf) {
            _busyPdf = false;
          } else {
            _busyXlsx = false;
          }
        });
      }
    }
  }
}
