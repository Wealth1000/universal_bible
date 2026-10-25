import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_bible/features/rhapsody/domain/devotional.dart';

const String _devotionalsTable = 'devotionals';

/// Reads devotionals from the Supabase `devotionals` table.
///
/// Requires a SELECT RLS policy on the table (the content is the same for
/// every reader, so a public/authenticated read policy is expected).
class SupabaseDevotionalRepository {
  SupabaseDevotionalRepository();

  SupabaseClient get _client => Supabase.instance.client;

  /// The devotional for [day] if present, otherwise the most recent one before
  /// it (so the reader always lands on real content). Falls back to the
  /// earliest available entry when [day] precedes everything in the table.
  Future<Devotional?> fetchForDate(DateTime day) async {
    final iso = _isoDate(day);

    final onOrBefore = await _client
        .from(_devotionalsTable)
        .select()
        .lte('date', iso)
        .order('date', ascending: false)
        .limit(1)
        .maybeSingle();

    if (onOrBefore != null) {
      return Devotional.fromRow(onOrBefore);
    }

    final earliest = await _client
        .from(_devotionalsTable)
        .select()
        .order('date', ascending: true)
        .limit(1)
        .maybeSingle();

    return earliest == null ? null : Devotional.fromRow(earliest);
  }

  static String _isoDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
