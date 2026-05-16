import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> saveBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  // Prefer the downloads directory if the platform supports it; fall back to
  // application documents otherwise.
  Directory dir;
  try {
    dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  } catch (_) {
    dir = await getApplicationDocumentsDirectory();
  }
  final safe = _safeName(filename);
  final path = '${dir.path}${Platform.pathSeparator}$safe';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return path;
}

String _safeName(String name) {
  return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
