import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/features/rhapsody/domain/devotional.dart';
import 'package:universal_bible/features/rhapsody/infrastructure/supabase_devotional_repository.dart';

final devotionalRepositoryProvider = Provider<SupabaseDevotionalRepository>(
  (ref) => SupabaseDevotionalRepository(),
);

/// Today's devotional (or the closest available past entry). Refreshable via
/// `ref.invalidate` for pull-to-retry.
final todayDevotionalProvider = FutureProvider<Devotional?>((ref) async {
  final repo = ref.watch(devotionalRepositoryProvider);
  return repo.fetchForDate(DateTime.now());
});
