import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/features/bible/domain/chapter_navigation.dart';

class CurrentTranslationNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

class CurrentBookNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? book) => state = book;
}

class CurrentChapterNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? chapter) => state = chapter;
}

final currentChapterProvider = NotifierProvider<CurrentChapterNotifier, int?>(
  CurrentChapterNotifier.new,
);

// --- Visible Location Provider (display-only, follows scroll) ---
// Tracks BOTH the book and chapter currently centred in the viewport, so the
// reader header can follow the scroll across chapter AND book boundaries
// (continuous reading drifts Genesis 50 -> Exodus 1). Display-only: navigation
// still lives in currentBook/currentChapter.
class VisibleLocationNotifier extends Notifier<ChapterRef?> {
  @override
  ChapterRef? build() => null;

  void set(ChapterRef? ref) => state = ref;
}

final visibleLocationProvider =
    NotifierProvider<VisibleLocationNotifier, ChapterRef?>(
      VisibleLocationNotifier.new,
    );

// Chapter-only visible tracker retained for the (inactive) mobile reader,
// which tracks chapter within a single book. The desktop reader uses
// [visibleLocationProvider] so its header can follow cross-book scroll.
class VisibleChapterNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? chapter) => state = chapter;
}

final visibleChapterProvider = NotifierProvider<VisibleChapterNotifier, int?>(
  VisibleChapterNotifier.new,
);

final currentTranslationProvider =
    NotifierProvider<CurrentTranslationNotifier, String?>(
      CurrentTranslationNotifier.new,
    );
final currentBookProvider = NotifierProvider<CurrentBookNotifier, int?>(
  CurrentBookNotifier.new,
);

// --- Verse Selection (§5) ---

/// Immutable reference to a single verse (translation-independent).
class VerseRef {
  final int book;
  final int chapter;
  final int verse;

  const VerseRef(this.book, this.chapter, this.verse);

  @override
  bool operator ==(Object other) =>
      other is VerseRef &&
      other.book == book &&
      other.chapter == chapter &&
      other.verse == verse;

  @override
  int get hashCode => Object.hash(book, chapter, verse);

  @override
  String toString() => '$book|$chapter|$verse';
}

/// Tap-selected verses in the reader. Non-contiguous selection is supported;
/// the §5 action panel and the (future) §6 compare panel both read this.
class SelectedVersesNotifier extends Notifier<Set<VerseRef>> {
  @override
  Set<VerseRef> build() => const {};

  void toggle(VerseRef ref) {
    final next = {...state};
    if (!next.remove(ref)) next.add(ref);
    state = next;
  }

  void clear() => state = const {};
}

final selectedVersesProvider =
    NotifierProvider<SelectedVersesNotifier, Set<VerseRef>>(
      SelectedVersesNotifier.new,
    );

/// Whether the §6 compare pane is open. The pane is only rendered while the
/// selection is non-empty (empty selection closes it visually).
class CompareOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool open) => state = open;
}

final compareOpenProvider = NotifierProvider<CompareOpenNotifier, bool>(
  CompareOpenNotifier.new,
);

/// Bumped after any highlight write so reader content re-fetches
/// per-chapter highlights.
class HighlightsVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final highlightsVersionProvider =
    NotifierProvider<HighlightsVersionNotifier, int>(
      HighlightsVersionNotifier.new,
    );
