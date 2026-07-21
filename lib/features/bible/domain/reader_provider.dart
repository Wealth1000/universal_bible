import 'package:flutter_riverpod/flutter_riverpod.dart';

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

// --- Visible Chapter Provider (display-only, follows scroll) ---
class VisibleChapterNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? chapter) => state = chapter;
}

final currentTranslationProvider =
    NotifierProvider<CurrentTranslationNotifier, String?>(
      CurrentTranslationNotifier.new,
    );
final currentBookProvider = NotifierProvider<CurrentBookNotifier, int?>(
  CurrentBookNotifier.new,
);
final visibleChapterProvider = NotifierProvider<VisibleChapterNotifier, int?>(
  VisibleChapterNotifier.new,
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
