import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/core/providers/database_provider.dart';
import 'package:universal_bible/core/utils/book_name_utils.dart';
import 'package:universal_bible/features/bible/data/bible_data_module.dart';
import 'package:universal_bible/features/bible/domain/book_info.dart';
import 'package:universal_bible/features/bible/domain/chapter_navigation.dart';
import 'package:universal_bible/features/bible/domain/continuous_reading_provider.dart';
import 'package:universal_bible/features/bible/domain/reader_provider.dart';
import 'package:universal_bible/features/bible/presentation/widgets/verse_action_panel.dart';
import 'package:universal_bible/core/providers/book_name_settings_provider.dart';
import 'package:uuid/uuid.dart';

/// Deep module that owns all reader state mutations. The presentation layer
/// reads providers for display values and calls this class for every change.
class ReaderSession {
  ReaderSession({required this.ref, required this.bibleData});

  final Ref ref;
  final BibleDataModule bibleData;

  // --- Internal state ---

  /// Cached book list for the current translation. Rebuilt when the
  /// translation changes or [reloadBooks] is called.
  List<BookInfo>? _books;

  /// Preloaded chapter data, keyed by "translationId|book|chapter".
  final Map<String, ChapterData> _chapterCache = {};
  static const int _maxCacheSize = 20;

  // --- Navigation ---

  /// Navigate to (book, chapter). Updates [currentBookProvider]/
  /// [currentChapterProvider] and persists via [readingPositionProvider].
  void navigateTo(ChapterRef target) {
    ref.read(currentBookProvider.notifier).set(target.book);
    ref.read(currentChapterProvider.notifier).set(target.chapter);
    _persistPosition(target.book, target.chapter);
  }

  // --- Scroll position ---

  /// Called by the reader widget after computing which chapter header is
  /// visible. Updates [visibleLocationProvider] and persists.
  void onScrollPositionUpdated(ChapterRef visibleChapter) {
    ref.read(visibleLocationProvider.notifier).set(visibleChapter);
    _persistPosition(visibleChapter.book, visibleChapter.chapter);
  }

  // --- Preloading (continuous reading) ---

  /// Returns true if a next chapter should be preloaded. Driven by scroll
  /// offset thresholds in the widget; the session just exposes whether
  /// continuous reading is enabled.
  bool shouldPreloadNext() => ref.read(continuousReadingProvider);

  /// Returns true if a previous chapter should be preloaded.
  bool shouldPreloadPrev() => ref.read(continuousReadingProvider);

  /// Load and return the next chapter's data, or null at end of Bible.
  Future<ChapterData?> preloadNext(int book, int chapter) async {
    final books = _books;
    final translationId = ref.read(currentTranslationProvider);
    if (books == null || translationId == null) return null;

    final target = nextChapterRef(books, book, chapter);
    if (target == null) return null;

    final cacheKey = '$translationId|$target.book|$target.chapter';
    if (_chapterCache.containsKey(cacheKey)) {
      return _chapterCache[cacheKey];
    }

    final data = await bibleData.getChapterData(
      translationId,
      target.book,
      target.chapter,
    );
    _chapterCache[cacheKey] = data;
    _trimCache();
    return data;
  }

  /// Load and return the previous chapter's data, or null at start of Bible.
  Future<ChapterData?> preloadPrev(int book, int chapter) async {
    final books = _books;
    final translationId = ref.read(currentTranslationProvider);
    if (books == null || translationId == null) return null;

    final target = prevChapterRef(books, book, chapter);
    if (target == null) return null;

    final cacheKey = '$translationId|$target.book|$target.chapter';
    if (_chapterCache.containsKey(cacheKey)) {
      return _chapterCache[cacheKey];
    }

    final data = await bibleData.getChapterData(
      translationId,
      target.book,
      target.chapter,
    );
    _chapterCache[cacheKey] = data;
    _trimCache();
    return data;
  }

  // --- Verse selection ---

  /// Toggle a verse in/out of selection. Returns the updated [Set].
  Set<VerseRef> toggleVerse(VerseRef verse) {
    ref.read(selectedVersesProvider.notifier).toggle(verse);
    return {...ref.read(selectedVersesProvider)};
  }

  /// Clear all selected verses and close compare.
  void clearSelection() {
    ref.read(selectedVersesProvider.notifier).clear();
    ref.read(compareOpenProvider.notifier).set(false);
  }

  /// Get the current sorted selection (reading order: book, chapter, verse).
  List<VerseRef> getSortedSelection() {
    return ref.read(selectedVersesProvider).toList()
      ..sort((a, b) {
        if (a.book != b.book) return a.book - b.book;
        if (a.chapter != b.chapter) return a.chapter - b.chapter;
        return a.verse - b.verse;
      });
  }

  /// Open the compare pane.
  void openCompare() => ref.read(compareOpenProvider.notifier).set(true);

  /// Close the compare pane.
  void closeCompare() => ref.read(compareOpenProvider.notifier).set(false);

  // --- Study actions ---

  /// Apply or remove a highlight color on all selected verses. Toggle-off
  /// when every selected verse already has exactly this color.
  Future<void> applyHighlight(Color color) async {
    final translationId = ref.read(currentTranslationProvider);
    final refs = getSortedSelection();
    if (translationId == null || refs.isEmpty) return;

    final hex = highlightColorToHex(color);

    var allAlreadyThisColor = true;
    for (final v in refs) {
      final chapterData = await bibleData.getChapterData(
        translationId,
        v.book,
        v.chapter,
      );
      final existing = chapterData.highlightsByVerse[
          VerseRef(v.book, v.chapter, v.verse)];
      if (existing == null || existing.color != hex) {
        allAlreadyThisColor = false;
        break;
      }
    }

    for (final v in refs) {
      if (!allAlreadyThisColor) {
        await bibleData.saveHighlight(
          id: const Uuid().v4(),
          translationId: translationId,
          bookNumber: v.book,
          chapter: v.chapter,
          verse: v.verse,
          color: hex,
          createdAt: DateTime.now(),
        );
      } else {
        await bibleData.deleteHighlightsForVerse(
          translationId,
          v.book,
          v.chapter,
          v.verse,
        );
      }
    }

    ref.read(highlightsVersionProvider.notifier).bump();
  }

  /// Insert bookmarks for all selected verses.
  Future<void> bookmarkSelection() async {
    final translationId = ref.read(currentTranslationProvider);
    final refs = getSortedSelection();
    if (translationId == null || refs.isEmpty) return;

    for (final v in refs) {
      await bibleData.insertBookmark(
        id: const Uuid().v4(),
        translationId: translationId,
        bookNumber: v.book,
        chapter: v.chapter,
        verse: v.verse,
        createdAt: DateTime.now(),
      );
    }
  }

  /// Insert notes for all selected verses. [content] is provided by the
  /// caller (the dialog lives in the view).
  Future<void> addNote(String content) async {
    final translationId = ref.read(currentTranslationProvider);
    final refs = getSortedSelection();
    if (translationId == null || refs.isEmpty) return;

    final now = DateTime.now();
    for (final v in refs) {
      await bibleData.insertNote(
        id: const Uuid().v4(),
        translationId: translationId,
        bookNumber: v.book,
        chapter: v.chapter,
        verse: v.verse,
        content: content,
        createdAt: now,
        updatedAt: now,
      );
    }
  }

  // --- State getters ---

  /// Returns the persisted reading position, or null.
  ReadingPosition? get persistedPosition => ref.read(readingPositionProvider);

  /// Returns whether continuous reading is enabled.
  bool get isContinuousReading => ref.read(continuousReadingProvider);

  /// Returns the current translation id.
  String? get currentTranslationId => ref.read(currentTranslationProvider);

  /// Returns the current book number.
  int? get currentBook => ref.read(currentBookProvider);

  /// Returns the current chapter number.
  int? get currentChapter => ref.read(currentChapterProvider);

  /// Returns the currently visible chapter (scroll-follow).
  ChapterRef? get visibleLocation => ref.read(visibleLocationProvider);

  // --- Book loading ---

  /// Rebuilds [_books] from the current translation and returns it.
  /// Called when the translation changes or [preserveOriginalBookNamesProvider]
  /// changes (the page listens to the latter and calls [reloadBooks]).
  Future<List<BookInfo>> _loadBooks() async {
    final translationId = ref.read(currentTranslationProvider);
    if (translationId == null) return [];

    final preserveOriginal = ref.read(preserveOriginalBookNamesProvider);
    final bookInfo = await bibleData.getBookInfo(translationId);

    final sortedEntries = bookInfo.bookMap.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final books = <BookInfo>[];
    for (final entry in sortedEntries) {
      final name = entry.key;
      final number = entry.value;
      final displayName = formatBookName(
        name,
        preserveOriginal: preserveOriginal,
      );
      final counts = bookInfo.chapterCounts[number] ?? {};
      books.add(
        BookInfo(number: number, name: displayName, chapterCounts: counts),
      );
    }

    _books = books;
    return books;
  }

  /// Public entry point for the view to trigger a book-list reload.
  Future<List<BookInfo>> reloadBooks() => _loadBooks();

  // --- Internal helpers ---

  void _trimCache() {
    while (_chapterCache.length > _maxCacheSize) {
      final firstKey = _chapterCache.keys.first;
      _chapterCache.remove(firstKey);
    }
  }

  void _persistPosition(int book, int chapter) {
    final translationId = ref.read(currentTranslationProvider);
    if (translationId == null) return;
    ref.read(readingPositionProvider.notifier).save(
      ReadingPosition(
        translationId: translationId,
        book: book,
        chapter: chapter,
      ),
    );
  }
}
