// Cross-platform "save bytes to user's device" helper. The web/native impls
// are picked via conditional imports so we never load dart:io on web or
// dart:html on native.

import 'download_helper_stub.dart'
    if (dart.library.io) 'download_helper_io.dart'
    if (dart.library.js_interop) 'download_helper_web.dart' as impl;

import 'dart:typed_data';

/// Saves `bytes` to the user's device under `filename` with the given mime
/// type. Returns a short, user-visible description of where it landed (e.g.
/// "Downloads" on web, or the actual path on native).
Future<String> saveBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) =>
    impl.saveBytes(bytes: bytes, filename: filename, mimeType: mimeType);
