import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// An export payload plus the filename the server chose for it.
class ExportFile {
  const ExportFile({required this.bytes, required this.filename});
  final Uint8List bytes;
  final String filename;
}

class ExportsRepository {
  ExportsRepository(this._dio);
  final Dio _dio;

  /// Monthly compliance report. Pass [projectId] to scope the report to one
  /// site — the server then names the file after that site and the month.
  Future<ExportFile> monthlyPdf({required String month, String? projectId}) =>
      _fetch(path: '/exports/monthly.pdf', month: month, projectId: projectId);

  Future<ExportFile> monthlyXlsx({required String month, String? projectId}) =>
      _fetch(path: '/exports/monthly.xlsx', month: month, projectId: projectId);

  Future<ExportFile> _fetch({
    required String path,
    required String month,
    String? projectId,
  }) async {
    final res = await _dio.get<List<int>>(
      path,
      queryParameters: {
        'month': month,
        'projectId': ?projectId,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    return ExportFile(
      bytes: Uint8List.fromList(res.data!),
      filename: filenameFromHeaders(res.headers, fallbackPath: path, month: month),
    );
  }
}

/// Reads the name off `Content-Disposition` so nomenclature stays defined in
/// one place (the backend). Falls back to a month-stamped name if the header is
/// missing or unparseable.
String filenameFromHeaders(
  Headers headers, {
  required String fallbackPath,
  required String month,
}) {
  final raw = headers.value('content-disposition');
  if (raw != null) {
    // Prefer RFC 5987 `filename*=UTF-8''name`, else plain `filename="name"`.
    final ext = RegExp(r"filename\*=(?:UTF-8'')?([^;]+)", caseSensitive: false)
        .firstMatch(raw);
    final plain =
        RegExp(r'filename="?([^";]+)"?', caseSensitive: false).firstMatch(raw);
    final name = (ext?.group(1) ?? plain?.group(1))?.trim();
    if (name != null && name.isNotEmpty) return Uri.decodeComponent(name);
  }
  final suffix = fallbackPath.endsWith('.pdf') ? 'pdf' : 'xlsx';
  return 'All-Sites_$month.$suffix';
}

final exportsRepositoryProvider = Provider<ExportsRepository>((ref) {
  return ExportsRepository(ref.watch(apiClientProvider));
});
