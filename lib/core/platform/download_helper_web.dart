import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// The browser decides where downloads land, so there is nothing to pick.
bool get supportsLocationPicker => false;

Future<String?> pickSaveDirectory() async => null;

Future<String> saveBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  // Accepted for signature parity with the native impl; the browser controls
  // the destination folder, so it is ignored.
  String? directory,
}) async {
  // Wrap bytes in a Blob and trigger a synthetic <a download> click.
  final part = bytes.toJS;
  final blob = web.Blob(
    [part].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..style.display = 'none'
    ..download = filename;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  // Give the browser a beat before revoking, so the download has the URL.
  Future<void>.delayed(const Duration(seconds: 5), () => web.URL.revokeObjectURL(url));
  return 'browser Downloads';
}
