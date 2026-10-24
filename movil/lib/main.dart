import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/ceos_theme.dart';
import 'providers/auth_provider.dart';

import 'providers/theme_provider.dart';
import 'widgets/fondo_ambiental.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  // Check persisted session on app startup
  await container.read(authNotifierProvider.notifier).checkAuthStatus();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CeosApp(),
    ),
  );
}

class CeosApp extends ConsumerWidget {
  const CeosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeNotifierProvider);

    return MaterialApp.router(
      title: 'CEOS — Gestión Dental',
      debugShowCheckedModeBanner: false,
      theme: CeosTheme.lightTheme,
      darkTheme: CeosTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => FondoAmbiental(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
