import 'package:go_router/go_router.dart';
import 'package:universal_bible/core/shell/app_shell.dart';
import 'package:universal_bible/features/bible/presentation/pages/reader_page_desktop.dart';
import 'package:universal_bible/features/bible/presentation/pages/compare_page_desktop.dart';
import 'package:universal_bible/features/bible/presentation/pages/bookmarks_page_desktop.dart';
import 'package:universal_bible/features/bible/presentation/pages/notes_page_desktop.dart';
import 'package:universal_bible/features/search/presentation/pages/search_page_desktop.dart';
import 'package:universal_bible/features/rhapsody/presentation/rhapsody_screen.dart';
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
      return translations.isNotEmpty ? '/reader' : '/translations';
    }
    return null; // no redirect
  },
  routes: [
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
          path: '/rhapsody',
          builder: (context, state) => const RhapsodyScreen(embedded: true),
        ),
        GoRoute(
          path: '/translations',
          builder: (context, state) => const TranslationManagerPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchPageDesktop(),
        ),
        // §6: full-screen comparison of the selected verses. Pushed (not
        // go'd) from the split-view compare pane so back returns to the
        // reader with the split view and selection intact.
        GoRoute(
          path: '/compare',
          builder: (context, state) => const ComparePageDesktop(),
        ),
        GoRoute(
          path: '/bookmarks',
          builder: (context, state) => const BookmarksPageDesktop(),
        ),
        GoRoute(
          path: '/notes',
          builder: (context, state) => const NotesPageDesktop(),
        ),
      ],
    ),
  ],
);
