import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/network/backend_controller.dart';

void main() {
  // Catch widget-tree errors. In debug we let Flutter's default red-screen
  // present; in release we log + swallow so a single broken widget doesn't
  // kill the app.
  FlutterError.onError = (details) {
    if (kReleaseMode) {
      FlutterError.dumpErrorToConsole(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  // Catch async errors that escape the widget tree (futures, streams, etc.).
  runZonedGuarded<void>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('Uncaught platform error: $error\n$stack');
        return true;
      };
      // Resolve which backend to talk to before the first request can fire, so
      // the Dio clients are built with the right base URL from the start.
      final backendUrl = await BackendUrlController.load();
      runApp(
        ProviderScope(
          overrides: [initialBackendUrlProvider.overrideWithValue(backendUrl)],
          child: const OpsApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('Uncaught zone error: $error\n$stack');
    },
  );
}
