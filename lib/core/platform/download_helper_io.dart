import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Desktop and Android can surface a real folder picker. iOS has no
/// user-browsable filesystem, so it keeps the app-documents default.
bool get supportsLocationPicker =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux || Platform.isAndroid;

Future<String?> pickSaveDirectory() async {
  if (!supportsLocationPicker) return null;
  try {
    return await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose where to save exports',
    );
  } catch (_) {
    // Picker unavailable (e.g. missing portal/zenity on Linux) — the caller
    // falls back to the default location.
    return null;
  }
}

Future<String> saveBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  String? directory,
}) async {
  final dir = await _resolveDir(directory);
  final safe = _safeName(filename);
  final path = '${dir.path}${Platform.pathSeparator}$safe';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return path;
}

Future<Directory> _resolveDir(String? directory) async {
  if (directory != null && directory.isNotEmpty) {
    final chosen = Directory(directory);
    // A remembered folder can disappear (unmounted drive, deleted). Fall back
    // to the default rather than failing the export outright.
    if (await chosen.exists()) return chosen;
  }
  // Prefer the downloads directory if the platform supports it; fall back to
  // application documents otherwise.
  try {
    return await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  } catch (_) {
    return getApplicationDocumentsDirectory();
  }
}

String _safeName(String name) {
  return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
