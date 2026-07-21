import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_bible/core/providers/translation_repo_provider.dart';
import 'package:universal_bible/core/utils/book_name_utils.dart';
import 'package:universal_bible/core/utils/scripture_format.dart';
import 'package:universal_bible/features/bible/domain/book_info.dart';
import 'package:universal_bible/features/bible/domain/chapter_navigation.dart';
import 'package:universal_bible/features/bible/domain/continuous_reading_provider.dart';
import 'package:universal_bible/features/bible/domain/reader_provider.dart';
import 'package:universal_bible/features/bible/presentation/widgets/translation_grid.dart';
import 'package:universal_bible/features/settings/domain/book_name_settings_provider.dart';
import 'dart:convert';
import '../../../../core/providers/database_provider.dart';
import '../../../../database/app_database.dart' hide ReadingPosition; // For Verse type

/// A chapter's verses together with its location, for rendering (and, in
/// continuous mode, appending) chapters in the reader.
class _LoadedChapter {
  final int book;
  final int chapter;
  final String bookName;
  final List<Verse> verses;

  const _LoadedChapter({
    required this.book,
    required this.chapter,
    required this.bookName,
    required this.verses,
  });
}

// --- Mobile Reader Page ---
class ReaderPageMobile extends ConsumerStatefulWidget {
  const ReaderPageMobile({super.key});

  @override
  ConsumerState<ReaderPageMobile> createState() => _ReaderPageMobileState();
}

class _ReaderPageMobileState extends ConsumerState<ReaderPageMobile> {
  List<BookInfo>? _books;
  Map<int, int>? _chapterCounts;
  bool _isLoading = true;

  // Verse selection state
  int? _selectedVerseId;
  bool _showContextMenu = false;

  // Cache the verses future so unrelated setState calls (verse taps,
  // context menu) don't recreate it — recreating it makes FutureBuilder
  // re-enter the waiting state, which flickers the reader and interrupts
  // any in-progress text selection.
  Future<List<Verse>>? _versesFuture;
  String? _versesKey;

  Future<List<Verse>> _ensureVersesFuture(
    String? translationId,
    int? book,
    int? chapter,
  ) {
    final key = '$translationId|$book|$chapter';
    if (_versesKey != key || _versesFuture == null) {
      _versesKey = key;
      _versesFuture = translationId != null && book != null && chapter != null
          ? ref
                .read(databaseProvider)
                .getVersesForChapter(translationId, book, chapter)
          : Future.value(<Verse>[]);
    }
    return _versesFuture!;
  }

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final repo = ref.read(translationRepoProvider);
    final translations = await repo.getInstalled();
    if (translations.isEmpty) {
      if (mounted) {
        context.go('/translations');
      }
      return;
    }

    // Persisted position (survives restarts). Only fills providers that
    // are still null, so in-session navigation is never overridden.
    final persisted = ref.read(readingPositionProvider);

    final currentTransId = ref.read(currentTranslationProvider);
    final persistedTransId =
        translations.any((t) => t.id == persisted?.translationId)
        ? persisted?.translationId
        : null;
    final transId = currentTransId ?? persistedTransId ?? translations.first.id;
    if (currentTransId == null) {
      ref.read(currentTranslationProvider.notifier).set(transId);
    }

    final trans = await repo.get(transId);
    if (trans == null) {
      setState(() => _isLoading = false);
      return;
    }

    final bookMapJson = trans.bookMapJson;
    final bookMap = jsonDecode(bookMapJson) as Map<String, dynamic>;

    final countsJson = trans.bookChapterCountsJson ?? '{}';
    final bookChaptersRaw = jsonDecode(countsJson) as Map<String, dynamic>;
    final bookChapters = <int, Map<int, int>>{};
    bookChaptersRaw.forEach((bookKey, chapters) {
      final bookNum = int.parse(bookKey);
      final chaptersMap = (chapters as Map<String, dynamic>).map(
        (chKey, count) => MapEntry(int.parse(chKey), count as int),
      );
      bookChapters[bookNum] = chaptersMap;
    });

    final sortedEntries = bookMap.entries.toList()
      ..sort((a, b) => (a.value as int).compareTo(b.value as int));

    final preserveOriginal = ref.read(preserveOriginalBookNamesProvider);
    final books = <BookInfo>[];
    for (final entry in sortedEntries) {
      final name = entry.key;
      final number = entry.value as int;
      final counts = bookChapters[number] ?? {};
      // Format at display time so name fixes apply without re-importing
      // the translation (bookDisplayNamesJson may be stale or missing).
      final displayName =
          formatBookName(name, preserveOriginal: preserveOriginal);
      books.add(BookInfo(
        number: number,
        name: displayName,
        chapterCounts: counts,
      ));
    }

    setState(() {
      _books = books;
      _isLoading = false;
      final currentBook = ref.read(currentBookProvider);
      final currentChapter = ref.read(currentChapterProvider);
      // Persisted book/chapter are used only when valid in THIS book map
      // (a different translation may lack them); otherwise first book /
      // first chapter as before.
      BookInfo? persistedBookInfo;
      if (persisted != null) {
        for (final b in books) {
          if (b.number == persisted.book) {
            persistedBookInfo = b;
            break;
          }
        }
      }
      if (currentBook == null && books.isNotEmpty) {
        ref
            .read(currentBookProvider.notifier)
            .set(persistedBookInfo?.number ?? books.first.number);
      }
      if (currentChapter == null && books.isNotEmpty) {
        // Persisted chapter applies only when the book also came from the
        // persisted position (currentBook was null too).
        final usePersisted = currentBook == null && persistedBookInfo != null;
        final targetBook = usePersisted ? persistedBookInfo : books.first;
        final int chapterToSet;
        if (usePersisted &&
            persistedBookInfo.chapterCounts.containsKey(persisted!.chapter)) {
          chapterToSet = persisted.chapter;
        } else {
          chapterToSet = targetBook.chapterCounts.keys.isNotEmpty
              ? (targetBook.chapterCounts.keys.toList()..sort()).first
              : 1;
        }
        ref.read(currentChapterProvider.notifier).set(chapterToSet);
      }
      final effectiveBook = ref.read(currentBookProvider);
      if (effectiveBook != null) {
        // After a translation switch the in-session book may not exist in
        // the new book map — clamp (don't reset) so the reader shows real
        // content. Chapter clamping happens in _updateChapterCounts.
        if (books.isNotEmpty && !books.any((b) => b.number == effectiveBook)) {
          ref.read(currentBookProvider.notifier).set(books.first.number);
          _updateChapterCounts(books.first.number);
        } else {
          _updateChapterCounts(effectiveBook);
        }
      }
    });
  }

  void _updateChapterCounts(int bookNumber) {
    final book = _books?.firstWhere(
      (b) => b.number == bookNumber,
      orElse: () => BookInfo(number: 0, name: '', chapterCounts: {}),
    );
    if (book != null && book.number != 0) {
      setState(() {
        _chapterCounts = book.chapterCounts;
        final currentChapter = ref.read(currentChapterProvider);
        if (currentChapter != null && !_chapterCounts!.containsKey(currentChapter)) {
          final firstChapter = _chapterCounts!.keys.isNotEmpty
              ? _chapterCounts!.keys.first
              : 1;
          ref.read(currentChapterProvider.notifier).set(firstChapter);
          // The new translation/book lacks the old chapter — persist the
          // clamped position so restore doesn't point at a missing chapter.
          _persistPosition(bookNumber, firstChapter);
        }
      });
    }
  }

  void _goTo(ChapterRef target) {
    ref.read(currentBookProvider.notifier).set(target.book);
    ref.read(currentChapterProvider.notifier).set(target.chapter);
    _updateChapterCounts(target.book);
    _persistPosition(target.book, target.chapter);
  }

  /// Persists (translation, book, chapter) so the reader reopens here.
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

  /// Loads the chapter after (book, chapter), crossing book boundaries.
  /// Returns null at the end of the last book.
  Future<_LoadedChapter?> _loadChapterAfter(int book, int chapter) async {
    final books = _books;
    final translationId = ref.read(currentTranslationProvider);
    if (books == null || translationId == null) return null;

    final target = nextChapterRef(books, book, chapter);
    if (target == null) return null;

    final verses = await ref
        .read(databaseProvider)
        .getVersesForChapter(translationId, target.book, target.chapter);
    return _LoadedChapter(
      book: target.book,
      chapter: target.chapter,
      bookName: bookNameFor(books, target),
      verses: verses,
    );
  }

  /// Loads the chapter before (book, chapter), crossing book boundaries.
  /// Returns null at the beginning of the first book.
  Future<_LoadedChapter?> _loadChapterBefore(int book, int chapter) async {
    final books = _books;
    final translationId = ref.read(currentTranslationProvider);
    if (books == null || translationId == null) return null;

    final target = prevChapterRef(books, book, chapter);
    if (target == null) return null;

    final verses = await ref
        .read(databaseProvider)
        .getVersesForChapter(translationId, target.book, target.chapter);
    return _LoadedChapter(
      book: target.book,
      chapter: target.chapter,
      bookName: bookNameFor(books, target),
      verses: verses,
    );
  }

  void _showBookPicker() {
    if (_books == null || _books!.isEmpty) return;

    final currentBook = ref.read(currentBookProvider);
    // Pre-scroll to the active book so it's visible on open.
    final currentIndex =
        _books!.indexWhere((b) => b.number == currentBook);
    final scrollController = ScrollController(
      initialScrollOffset: currentIndex > 0
          ? (currentIndex * 56.0).clamp(0.0, double.infinity)
          : 0.0,
    );

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Select Book',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _books!.length,
                  itemBuilder: (context, index) {
                    final book = _books![index];
                    final isActive = book.number == currentBook;
                    return ListTile(
                      title: Text(book.name),
                      selected: isActive,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      selectedTileColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.4),
                      trailing: isActive
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                              size: 18,
                            )
                          : null,
                      onTap: () {
                        // Always navigate to the first chapter of the new
                        // book — same as the desktop onBookChanged handler.
                        final sortedChapters =
                            book.chapterCounts.keys.toList()..sort();
                        final firstChapter =
                            sortedChapters.isNotEmpty ? sortedChapters.first : 1;
                        _goTo(ChapterRef(book.number, firstChapter));
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => scrollController.dispose());
  }

  void _showChapterPicker() {
    if (_chapterCounts == null || _chapterCounts!.isEmpty) return;

    final chapters = _chapterCounts!.keys.toList()..sort();
    final currentChapter = ref.read(currentChapterProvider);
    final currentIndex = chapters.indexOf(currentChapter ?? -1);
    final scrollController = ScrollController(
      initialScrollOffset: currentIndex > 0
          ? (currentIndex * 56.0).clamp(0.0, double.infinity)
          : 0.0,
    );

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Select Chapter',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    final isActive = chapter == currentChapter;
                    return ListTile(
                      title: Text('Chapter $chapter'),
                      selected: isActive,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      selectedTileColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.4),
                      trailing: isActive
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                              size: 18,
                            )
                          : null,
                      onTap: () {
                        ref
                            .read(currentChapterProvider.notifier)
                            .set(chapter);
                        final book = ref.read(currentBookProvider);
                        if (book != null) _persistPosition(book, chapter);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => scrollController.dispose());
  }

  void _showTranslationPicker() {
    // §2: grid of installed translations. Switching keeps book/chapter.
    showTranslationGridSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild book names when the "preserve original names" toggle changes.
    ref.listen(preserveOriginalBookNamesProvider, (prev, next) {
      if (prev != next) _loadBooks();
    });
    // Reload the book map when the translation changes (pill switch) —
    // book names / chapter counts differ per translation. Book & chapter
    // providers are non-null here, so _loadBooks leaves them untouched
    // (only clamping via _updateChapterCounts if the chapter is missing)
    // and the reader stays at the same position.
    ref.listen(currentTranslationProvider, (prev, next) {
      if (prev != null && next != null && prev != next) _loadBooks();
    });

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? colorScheme.primary : const Color(0xFF2E434C);

    final translationId = ref.watch(currentTranslationProvider);
    final book = ref.watch(currentBookProvider);
    final chapter = ref.watch(currentChapterProvider);
    final continuousReading = ref.watch(continuousReadingProvider);

    // Read the visible chapter for the AppBar label (from scroll-follow).
    final visibleChapter = ref.watch(visibleChapterProvider) ?? chapter;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: primaryColor,
          ),
        ),
      );
    }

    if (_books == null || _books!.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.translate,
                size: 48,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No translations installed.',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/translations'),
                child: const Text('Import a translation'),
              ),
            ],
          ),
        ),
      );
    }

    final currentBookInfo = _books!.firstWhere(
      (b) => b.number == book,
      orElse: () => _books!.first,
    );
    final bookName = currentBookInfo.name;
    final chapterCounts = currentBookInfo.chapterCounts;
    final chapterKeys = chapterCounts.keys.toList()..sort();
    final currentChapter = chapter ?? (chapterKeys.isNotEmpty ? chapterKeys.first : 1);
    final currentBook = currentBookInfo.number;

    final prevRef = prevChapterRef(_books!, currentBook, currentChapter);
    final nextRef = nextChapterRef(_books!, currentBook, currentChapter);

    final versesFuture = _ensureVersesFuture(translationId, book, chapter);

    final displayTranslation = translationId?.toUpperCase() ?? 'KJV';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Book picker
            GestureDetector(
              onTap: _showBookPicker,
              child: Row(
                children: [
                  Text(
                    bookName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more,
                    size: 18,
                    color: primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '•',
              style: TextStyle(
                color: colorScheme.outlineVariant,
              ),
            ),
            const SizedBox(width: 8),
            // Chapter label (follows scroll when continuous reading is on)
            GestureDetector(
              onTap: _showChapterPicker,
              child: Row(
                children: [
                  Text(
                    '$visibleChapter',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more,
                    size: 18,
                    color: primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '•',
              style: TextStyle(
                color: colorScheme.outlineVariant,
              ),
            ),
            const SizedBox(width: 8),
            // Translation pill (§2): opens the grid picker.
            Semantics(
              button: true,
              label:
                  'Active translation: $displayTranslation. Tap to switch.',
              child: GestureDetector(
                onTap: _showTranslationPicker,
                child: Row(
                  children: [
                    Text(
                      displayTranslation,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.expand_more,
                      size: 18,
                      color: primaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          // Search shortcut (§7): secondary entry point to the Search
          // screen, alongside the bottom-bar item.
          IconButton(
            icon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
            tooltip: 'Search',
            onPressed: () => context.go('/search'),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
            tooltip: 'Reader options',
            onSelected: (value) {
              if (value == 'continuous') {
                ref
                    .read(continuousReadingProvider.notifier)
                    .set(!continuousReading);
              }
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem<String>(
                value: 'continuous',
                checked: continuousReading,
                child: const Text('Continuous reading'),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<Verse>>(
        future: versesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading verses: ${snapshot.error}',
                style: theme.textTheme.bodyMedium,
              ),
            );
          }
          final verses = snapshot.data ?? [];
          if (verses.isEmpty) {
            return const Center(
              child: Text('No verses found for this chapter.'),
            );
          }

          return Stack(
            children: [
              _ReaderScroll(
                // Reset loaded chapters and scroll when the user navigates
                // or toggles continuous mode.
                key: ValueKey(
                  '$translationId|$currentBook|$currentChapter|$continuousReading',
                ),
                initialChapter: _LoadedChapter(
                  book: currentBook,
                  chapter: currentChapter,
                  bookName: bookName,
                  verses: verses,
                ),
                continuousReading: continuousReading,
                prevLabel: prevRef == null
                    ? null
                    : '${bookNameFor(_books!, prevRef)} ${prevRef.chapter}',
                nextLabel: nextRef == null
                    ? null
                    : '${bookNameFor(_books!, nextRef)} ${nextRef.chapter}',
                onPrev: prevRef == null ? null : () => _goTo(prevRef),
                onNext: nextRef == null ? null : () => _goTo(nextRef),
                loadChapterAfter: _loadChapterAfter,
                loadChapterBefore: _loadChapterBefore,
                selectedVerseId: _selectedVerseId,
                onVerseTap: (verse) {
                  setState(() {
                    if (_selectedVerseId == verse.id) {
                      _selectedVerseId = null;
                      _showContextMenu = false;
                    } else {
                      _selectedVerseId = verse.id;
                      _showContextMenu = true;
                    }
                  });
                },
                onVerseLongPress: (verse) {
                  setState(() {
                    _selectedVerseId = verse.id;
                    _showContextMenu = true;
                  });
                },
              ),
              // Floating Context Menu (appears above selected verse)
              if (_showContextMenu && _selectedVerseId != null)
                Positioned(
                  top: 80, // Adjust based on the verse position
                  left: 0,
                  right: 0,
                  child: _ContextMenuMobile(
                    onHighlight: () {
                      // TODO: Implement highlight
                      setState(() => _showContextMenu = false);
                    },
                    onBookmark: () {
                      // TODO: Implement bookmark
                      setState(() => _showContextMenu = false);
                    },
                    onNote: () {
                      // TODO: Implement note
                      setState(() => _showContextMenu = false);
                    },
                    onCopy: () {
                      // TODO: Implement copy
                      setState(() => _showContextMenu = false);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// --- Scrollable chapter content (supports continuous reading) ---
class _ReaderScroll extends ConsumerStatefulWidget {
  final _LoadedChapter initialChapter;
  final bool continuousReading;
  final String? prevLabel;
  final String? nextLabel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final Future<_LoadedChapter?> Function(int book, int chapter) loadChapterAfter;
  final Future<_LoadedChapter?> Function(int book, int chapter) loadChapterBefore;
  final int? selectedVerseId;
  final Function(Verse) onVerseTap;
  final Function(Verse) onVerseLongPress;

  const _ReaderScroll({
    super.key,
    required this.initialChapter,
    required this.continuousReading,
    required this.prevLabel,
    required this.nextLabel,
    required this.onPrev,
    required this.onNext,
    required this.loadChapterAfter,
    required this.loadChapterBefore,
    required this.selectedVerseId,
    required this.onVerseTap,
    required this.onVerseLongPress,
  });

  @override
  ConsumerState<_ReaderScroll> createState() => _ReaderScrollState();
}

class _ReaderScrollState extends ConsumerState<_ReaderScroll> {
  final ScrollController _scrollController = ScrollController();
  // Anchors the ListView so the scroll listener can measure header positions.
  final GlobalKey _scrollKey = GlobalKey();
  late final List<_LoadedChapter> _chapters = [widget.initialChapter];
  // One key per chapter header — updated when chapters are appended/prepended.
  final List<GlobalKey> _chapterHeaderKeys = [GlobalKey()];
  bool _loadingNext = false;
  bool _reachedEnd = false;
  bool _loadingPrev = false;
  bool _reachedStart = false;

  @override
  void initState() {
    super.initState();
    // Set the visible chapter after the first frame to avoid modifying provider during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(visibleChapterProvider.notifier).set(widget.initialChapter.chapter);
      }
    });

    // Always track which chapter header is visually centred.
    _scrollController.addListener(_updateVisibleChapter);

    if (widget.continuousReading) {
      _scrollController.addListener(_maybeLoadNext);
      _scrollController.addListener(_maybeLoadPrev);
      // A short chapter may not fill the viewport, leaving nothing to
      // scroll — check once after the first layout. We only prefetch the
      // NEXT chapter here: prefetching the previous one on open would
      // prepend content above offset 0 and jump the view to the prior
      // chapter/book. Previous chapters load only when the user scrolls up.
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadNext());
    }
  }

  /// Updates [visibleChapterProvider] to the chapter whose header is at or
  /// above the vertical midpoint of the viewport.  We walk from the last
  /// header backwards; the first one whose top edge ≤ half the viewport
  /// height is what the user is currently reading.
  void _updateVisibleChapter() {
    if (!mounted || !_scrollController.hasClients) return;

    final listCtx = _scrollKey.currentContext;
    if (listCtx == null) return;
    final listBox = listCtx.findRenderObject() as RenderBox?;
    if (listBox == null) return;

    final halfViewport = _scrollController.position.viewportDimension * 0.5;

    for (var i = _chapterHeaderKeys.length - 1; i >= 0; i--) {
      final headerCtx = _chapterHeaderKeys[i].currentContext;
      if (headerCtx == null) continue;
      final headerBox = headerCtx.findRenderObject() as RenderBox?;
      if (headerBox == null) continue;

      final topInViewport =
          listBox.globalToLocal(headerBox.localToGlobal(Offset.zero)).dy;

      if (topInViewport <= halfViewport) {
        ref.read(visibleChapterProvider.notifier).set(_chapters[i].chapter);
        // Persist the centered chapter so the reader reopens here — this
        // covers continuous-mode reading (incl. cross-book drift), which
        // never goes through navigation. Debounced inside the notifier.
        final translationId = ref.read(currentTranslationProvider);
        if (translationId != null) {
          ref.read(readingPositionProvider.notifier).save(
                ReadingPosition(
                  translationId: translationId,
                  book: _chapters[i].book,
                  chapter: _chapters[i].chapter,
                ),
              );
        }
        return;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _maybeLoadNext() async {
    if (_loadingNext || _reachedEnd || !mounted) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 600) return;

    _loadingNext = true;
    final last = _chapters.last;
    final next = await widget.loadChapterAfter(last.book, last.chapter);
    if (!mounted) return;
    setState(() {
      if (next == null || next.verses.isEmpty) {
        _reachedEnd = true;
      } else {
        _chapters.add(next);
        // Key for the new chapter's header; scroll listener will update
        // visibleChapterProvider when the header enters the viewport.
        _chapterHeaderKeys.add(GlobalKey());
      }
      _loadingNext = false;
    });
    // The appended chapter may still not fill the viewport (short chapters).
    if (next != null && next.verses.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadNext());
    }
  }

  Future<void> _maybeLoadPrev() async {
    if (_loadingPrev || _reachedStart || !mounted) return;
    if (!_scrollController.hasClients) return;
    // Only load if scrolled near the top (within 100 pixels of top)
    if (_scrollController.position.pixels > 100) return;

    _loadingPrev = true;
    final first = _chapters.first;
    final prev = await widget.loadChapterBefore(first.book, first.chapter);
    if (!mounted) return;
    if (prev == null || prev.verses.isEmpty) {
      setState(() {
        _reachedStart = true;
        _loadingPrev = false;
      });
      return;
    }
    // Capture extent before insert so we can keep the user's visual
    // position after the prepended chapter grows the list above them.
    final oldMaxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    setState(() {
      // Prepend the chapter and a header key; the scroll listener will
      // move visibleChapterProvider back when the user scrolls up to it.
      _chapters.insert(0, prev);
      _chapterHeaderKeys.insert(0, GlobalKey());
    });
    // After layout, jump forward by the height of the inserted content so
    // the viewport still shows the same verses — without this the view
    // stays at pixel 0 and "teleports" into the prepended chapter.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        _loadingPrev = false;
        return;
      }
      final newMaxExtent = _scrollController.position.maxScrollExtent;
      final delta = newMaxExtent - oldMaxExtent;
      if (delta > 0) {
        _scrollController.jumpTo(_scrollController.position.pixels + delta);
      }
      _loadingPrev = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SelectionArea(
        // One selection region for the whole chapter so long-press
        // text selection flows continuously across verses.
        child: ListView(
          key: _scrollKey,
          controller: _scrollController,
          children: [
            for (var i = 0; i < _chapters.length; i++) ...[
              const SizedBox(height: 16),
              Center(
                // Key lets _updateVisibleChapter locate this header's
                // on-screen position via the render tree.
                key: _chapterHeaderKeys[i],
                child: Column(
                  children: [
                    Text(
                      _chapters[i].bookName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chapter ${_chapters[i].chapter}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ..._chapters[i].verses.map((verse) {
                return _VerseTileMobile(
                  verseNumber: verse.verse,
                  text: verse.verseText,
                  isSelected: widget.selectedVerseId == verse.id,
                  onTap: () => widget.onVerseTap(verse),
                  onLongPress: () => widget.onVerseLongPress(verse),
                );
              }),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 16),
            if (widget.continuousReading && !_reachedEnd)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              _ChapterNavButtonsMobile(
                prevLabel: widget.prevLabel,
                nextLabel: widget.nextLabel,
                onPrev: widget.onPrev,
                onNext: widget.onNext,
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// --- Previous / Next chapter buttons ---
class _ChapterNavButtonsMobile extends StatelessWidget {
  final String? prevLabel;
  final String? nextLabel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _ChapterNavButtonsMobile({
    required this.prevLabel,
    required this.nextLabel,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;

    final style = TextButton.styleFrom(
      side: BorderSide(color: colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (onPrev != null)
          Flexible(
            child: TextButton(
              onPressed: onPrev,
              style: style,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 16, color: onSurfaceVariant),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      prevLabel!,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (onPrev != null && onNext != null) const SizedBox(width: 12),
        if (onNext != null)
          Flexible(
            child: TextButton(
              onPressed: onNext,
              style: style,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      nextLabel!,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 16, color: onSurfaceVariant),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// --- Mobile Verse Tile ---
class _VerseTileMobile extends StatefulWidget {
  final int verseNumber;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _VerseTileMobile({
    required this.verseNumber,
    required this.text,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_VerseTileMobile> createState() => _VerseTileMobileState();
}

class _VerseTileMobileState extends State<_VerseTileMobile> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final baseStyle = theme.textTheme.bodyLarge!.copyWith(
      fontFamily: 'Literata',
      fontSize: 16,
      height: 1.6,
      color: colorScheme.onSurface,
    );

    // Strip HTML, decode entities, and keep words-of-Christ segments
    // (red-letter) via sentinel markers.
    final normalized = normalizeResolvedScriptureText(
      widget.text,
      preserveWordsOfChrist: true,
    );
    final spans = buildScriptureSpans(
      normalized,
      baseStyle: baseStyle,
      wordsOfChristColor: wordsOfChristColorFor(theme.brightness),
    );

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? (isDark ? Colors.grey.shade800 : const Color(0xFFE3F2FD))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verse number
            SizedBox(
              width: 32,
              child: Text(
                '${widget.verseNumber}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: widget.isSelected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  fontSize: 12,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 12),
            // Verse text
            Expanded(
              child: Text.rich(TextSpan(children: spans)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Context Menu (Floating) ---
class _ContextMenuMobile extends StatelessWidget {
  final VoidCallback onHighlight;
  final VoidCallback onBookmark;
  final VoidCallback onNote;
  final VoidCallback onCopy;

  const _ContextMenuMobile({
    required this.onHighlight,
    required this.onBookmark,
    required this.onNote,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Highlight button
            _ContextMenuItem(
              icon: Icons.format_color_fill,
              label: 'Highlight',
              onTap: onHighlight,
              iconColor: Colors.yellow.shade600,
            ),
            Container(
              width: 1,
              height: 24,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            // Bookmark button
            _ContextMenuItem(
              icon: Icons.bookmark,
              label: '',
              onTap: onBookmark,
              isIconOnly: true,
            ),
            // Note button
            _ContextMenuItem(
              icon: Icons.sticky_note_2,
              label: '',
              onTap: onNote,
              isIconOnly: true,
            ),
            // Copy button
            _ContextMenuItem(
              icon: Icons.content_copy,
              label: '',
              onTap: onCopy,
              isIconOnly: true,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Context Menu Item ---
class _ContextMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isIconOnly;
  final Color? iconColor;

  const _ContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isIconOnly = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isIconOnly ? 12 : 16,
          vertical: 8,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? Colors.white,
              size: 20,
            ),
            if (!isIconOnly) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}