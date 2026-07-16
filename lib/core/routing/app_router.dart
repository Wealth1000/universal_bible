import 'package:go_router/go_router.dart';
import 'package:universal_bible/core/shell/app_shell.dart';
import 'package:universal_bible/features/auth/presentation/pages/welcome_page.dart';
import 'package:universal_bible/features/auth/presentation/pages/login_page.dart';
import 'package:universal_bible/features/bible/presentation/pages/reader_page_desktop.dart';
import 'package:universal_bible/features/bible/presentation/pages/reader_page_mobile.dart';
import 'package:universal_bible/features/settings/presention/pages/settings_page.dart';
import 'package:universal_bible/features/translation_manager/presentation/pages/translation_manager_page.dart';
import 'package:universal_bible/core/providers/translation_repo_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    // Only check when at the root path
    if (state.uri.path == '/') {
      final container = ProviderScope.containerOf(context);
      final repo = container.read(translationRepoProvider);
      final translations = await repo.getInstalled();
      return translations.isNotEmpty ? '/reader' : '/welcome';
    }
    return null; // no redirect
  },
  routes: [
    GoRoute(path: '/welcome', builder: (context, state) => const WelcomePage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    // Main destinations live inside the persistent shell (sidebar on
    // desktop, bottom bar on mobile) so navigation doesn't rebuild it.
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/reader',
          builder: (context, state) => const ReaderPageDesktop(),
        ),
        GoRoute(
          path: '/reader_mobile',
          builder: (context, state) => const ReaderPageMobile(),
        ),
        GoRoute(
          path: '/translations',
          builder: (context, state) => const TranslationManagerPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);
