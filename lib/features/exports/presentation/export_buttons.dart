import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/platform/download_helper.dart';
import '../../../core/vistar/widgets.dart';
import '../data/exports_repository.dart';

class ExportButtons extends ConsumerStatefulWidget {
  const ExportButtons({super.key, required this.month});
  final String month;

  @override
  ConsumerState<ExportButtons> createState() => _ExportButtonsState();
}

class _ExportButtonsState extends ConsumerState<ExportButtons> {
  bool _busyPdf = false;
  bool _busyXlsx = false;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        RibbonButton(
          small: true,
          onPressed: _busyPdf ? null : () => _doExport(pdf: true),
          icon: Icons.picture_as_pdf_outlined,
          label: _busyPdf ? 'Saving PDF…' : 'Export PDF',
        ),
        RibbonButton(
          small: true,
          onPressed: _busyXlsx ? null : () => _doExport(pdf: false),
          icon: Icons.table_chart_outlined,
          label: _busyXlsx ? 'Saving Excel…' : 'Export Excel',
        ),
      ],
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
      final bytes = pdf
          ? await repo.monthlyPdf(month: widget.month)
          : await repo.monthlyXlsx(month: widget.month);
      final filename = pdf
          ? 'opsapp-${widget.month}.pdf'
          : 'opsapp-${widget.month}.xlsx';
      final mime = pdf
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      final where =
          await saveBytes(bytes: bytes, filename: filename, mimeType: mime);
      messenger.showSnackBar(SnackBar(content: Text('Saved $filename to $where.')));
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
