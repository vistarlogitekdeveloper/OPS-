import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/platform/download_helper.dart';

const _kExportDirKey = 'opsapp.export_dir';

/// The folder exports are written to, remembered across launches. Null means
/// "platform default" (Downloads on desktop, the browser's own folder on web).
class ExportLocationController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    if (!supportsLocationPicker) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kExportDirKey);
  }

  /// Prompts for a folder and remembers it. Returns the chosen path, or null if
  /// the user cancelled (in which case the previous choice is left alone).
  Future<String?> choose() async {
    final picked = await pickSaveDirectory();
    if (picked == null || picked.isEmpty) return null;
    state = AsyncData(picked);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kExportDirKey, picked);
    return picked;
  }

  /// Reverts to the platform default location.
  Future<void> clear() async {
    state = const AsyncData(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kExportDirKey);
  }
}

final exportLocationProvider =
    AsyncNotifierProvider<ExportLocationController, String?>(
  ExportLocationController.new,
);
