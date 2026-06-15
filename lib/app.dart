import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/application/theme_controller.dart';
import 'features/splash/splash_screen.dart';

class OpsApp extends ConsumerWidget {
  const OpsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref
        .watch(themeControllerProvider)
        .maybeWhen(data: (m) => m, orElse: () => ThemeMode.system);
    return MaterialApp.router(
      title: 'Vistar OPS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => SplashGate(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
