import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/app_router.dart';
import 'core/themes/theme_provider.dart';
import 'core/themes/app_theme.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final themeData = ref.watch(themeDataProvider);

    return MaterialApp.router(
      title: 'Bible Project',
      theme: themeData,
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // ---- FIX: Lock the ENTIRE UI scale (not just text) to 100 % ----
        final mediaQuery = MediaQuery.of(context);
        const double targetDevicePixelRatio = 1.0; // 1.0 = no system scaling

        // If the system already reports 1.0, only lock the text scaler
        if ((mediaQuery.devicePixelRatio - targetDevicePixelRatio).abs() < 0.001) {
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: child!,
          );
        }

        // Otherwise, scale the logical size so the physical pixel grid stays correct
        final scale = mediaQuery.devicePixelRatio / targetDevicePixelRatio;
        return MediaQuery(
          data: mediaQuery.copyWith(
            devicePixelRatio: targetDevicePixelRatio,
            size: Size(
              mediaQuery.size.width * scale,
              mediaQuery.size.height * scale,
            ),
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }
}