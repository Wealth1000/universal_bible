import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/core/providers/translation_repo_provider.dart';
import 'package:universal_bible/core/providers/reader_navigation_provider.dart';
import 'package:universal_bible/features/rhapsody/domain/devotional.dart';
import 'package:universal_bible/features/rhapsody/infrastructure/supabase_devotional_repository.dart';
import 'package:universal_bible/features/rhapsody/application/scripture_resolver.dart';

final devotionalRepositoryProvider = Provider<SupabaseDevotionalRepository>(
  (ref) => SupabaseDevotionalRepository(),
);

/// Today's devotional (or the closest available past entry). Refreshable via
/// `ref.invalidate` for pull-to-retry.
final todayDevotionalProvider = FutureProvider<Devotional?>((ref) async {
  final repo = ref.watch(devotionalRepositoryProvider);
  return repo.fetchForDate(DateTime.now());
});

/// Deep module provider: constructs a [ScriptureResolver] wired to the shared
/// [BibleDataModule].
final scriptureResolverProvider = Provider<ScriptureResolver>((ref) {
  final bibleData = ref.watch(bibleDataModuleProvider);
  return ScriptureResolver(bibleData: bibleData);
});

/// Async passage resolver, cached per-reference string. Re-exports the same
/// shape that [_ScriptureRevealSheet] originally consumed so the widget
/// layer stays untouched.
final scripturePassageProvider =
    FutureProvider.family<ResolvedPassage, String>((ref, reference) async {
  final resolver = ref.read(scriptureResolverProvider);
  final currentTrans = ref.read(currentTranslationProvider);
  return resolver.resolve(reference, forcedTranslationId: currentTrans);
});
