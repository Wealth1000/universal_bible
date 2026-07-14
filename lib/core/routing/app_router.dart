import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/features/auth/presentation/pages/welcome_page.dart';
import 'package:universal_bible/features/auth/presentation/pages/login_page.dart';
import 'package:universal_bible/features/bible/presentation/pages/reader_page_desktop.dart';
import 'package:universal_bible/features/bible/presentation/pages/reader_page_mobile.dart';
import 'package:universal_bible/features/translation_manager/presentation/pages/translation_manager_page.dart';
import 'package:universal_bible/core/providers/database_provider.dart';
import 'package:universal_bible/features/bible/data/repositories/translation_repository.dart';

// Provider needed for the redirect
final _translationRepoProvider = Provider<TranslationRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TranslationRepository(db);
});

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    // Only check when at the root path
    if (state.uri.path == '/') {
      // Get the Riverpod container and read the repository
      final container = ProviderScope.containerOf(context);
      final repo = container.read(_translationRepoProvider);
      final translations = await repo.getInstalled();
      if (translations.isNotEmpty) {
        return '/reader';
      } else {
        return '/welcome';
      }
    }
    return null; // no redirect
  },
  routes: [
    GoRoute(path: '/welcome', builder: (context, state) => const WelcomePage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/reader',
      builder: (context, state) => const ReaderPageDesktop(),
    ),
    GoRoute(
      path: 'reader_mobile',
      builder: (context, state) => const ReaderPageMobile(),
    ),
    GoRoute(
      path: '/translations',
      builder: (context, state) => const TranslationManagerPage(),
    ),
    // Add more routes later
  ],
);
