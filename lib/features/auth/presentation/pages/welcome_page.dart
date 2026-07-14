import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
//import 'package:universal_bible/core/themes/app_theme.dart';//TODO: Expand AppTheme.

class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use design system colors
    final primaryColor = isDark
        ? theme.colorScheme.primary
        : const Color(0xFF2E434C);
    final onPrimary = isDark
        ? theme.colorScheme.onPrimary
        : Colors.white;
    final surfaceColor = theme.scaffoldBackgroundColor;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    final outline = theme.colorScheme.outline;

    return Scaffold(
      backgroundColor: surfaceColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top: App Logo (using SVG)
                  Column(
                    children: [
                      const SizedBox(height: 16),
                      // Use the actual PNG logo
                      Image.asset(
                        'assets/images/app_logo.png',
                        width: 64,
                        height: 64,
                        // If your SVG has colors that should adapt to theme,
                        // you can use colorFilter, but usually the logo is fixed.
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Universal Bible',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),

                  // Middle: Hero content (same as before)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          'Welcome to Universal Bible',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: onSurface,
                            fontSize: 28,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Read Scripture offline. Study anywhere. A sanctuary for focus and deep reflection.',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: onSurfaceVariant,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                  // Bottom: Buttons (unchanged)
                  Column(
                    children: [
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => context.go('/login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Sign In',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.login, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () => context.go('/reader'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(color: outline),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'Continue Offline',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 20,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => context.go('/translations'),
                        style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                        ),
                        child: const Text(
                          'Import Translation',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            decoration: TextDecoration.underline,
                            decorationThickness: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Version 2.4.0', // TODO: read from pubspec
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: outline.withValues(alpha: 0.6),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}