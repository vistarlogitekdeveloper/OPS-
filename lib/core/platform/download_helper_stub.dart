import 'dart:typed_data';

// Used only when neither dart:io nor dart:js_interop is available (e.g. some
// pure-Dart test runs). The real impls are download_helper_io.dart and
// download_helper_web.dart.
bool get supportsLocationPicker => false;

Future<String?> pickSaveDirectory() async => null;

Future<String> saveBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  String? directory,
}) async {
  throw UnsupportedError('saveBytes is not supported on this platform');
}
