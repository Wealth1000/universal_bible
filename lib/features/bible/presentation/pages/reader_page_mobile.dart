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
import 'package:universal_bible/features/settings/domain/book_name_settings_provider.dart';
import 'dart:convert';
import '../../../../core/providers/database_provider.dart';
import '../../../../database/app_database.dart'; // For Verse type

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

    final currentTransId = ref.read(currentTranslationProvider);
    final transId = currentTransId ?? translations.first.id;
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
      if (currentBook == null && books.isNotEmpty) {
        ref.read(currentBookProvider.notifier).set(books.first.number);
      }
      if (currentChapter == null && books.isNotEmpty) {
        final firstBook = books.first;
        final firstChapter = firstBook.chapterCounts.keys.isNotEmpty
            ? firstBook.chapterCounts.keys.first
            : 1;
        ref.read(currentChapterProvider.notifier).set(firstChapter);
      }
      if (currentBook != null) {
        _updateChapterCounts(currentBook);
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
        }
      });
    }
  }

  void _goTo(ChapterRef target) {
    ref.read(currentBookProvider.notifier).set(target.book);
    ref.read(currentChapterProvider.notifier).set(target.chapter);
    _updateChapterCounts(target.book);
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

  void _showBookPicker() {
    if (_books == null || _books!.isEmpty) return;

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
                  itemCount: _books!.length,
                  itemBuilder: (context, index) {
                    final book = _books![index];
                    return ListTile(
                      title: Text(book.name),
                      onTap: () {
                        ref.read(currentBookProvider.notifier).set(book.number);
                        _updateChapterCounts(book.number);
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
    );
  }

  void _showChapterPicker() {
    if (_chapterCounts == null || _chapterCounts!.isEmpty) return;

    final chapters = _chapterCounts!.keys.toList()..sort();

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
                  itemCount: chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    return ListTile(
                      title: Text('Chapter $chapter'),
                      onTap: () {
                        ref.read(currentChapterProvider.notifier).set(chapter);
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
    );
  }

  void _showTranslationPicker() {
    // TODO: Show available translations
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild book names when the "preserve original names" toggle changes.
    ref.listen(preserveOriginalBookNamesProvider, (prev, next) {
      if (prev != next) _loadBooks();
    });

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? colorScheme.primary : const Color(0xFF2E434C);

    final translationId = ref.watch(currentTranslationProvider);
    final book = ref.watch(currentBookProvider);
    final chapter = ref.watch(currentChapterProvider);
    final continuousReading = ref.watch(continuousReadingProvider);

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
            // Chapter picker
            GestureDetector(
              onTap: _showChapterPicker,
              child: Row(
                children: [
                  Text(
                    '$currentChapter',
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
            // Translation picker
            GestureDetector(
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
          ],
        ),
        centerTitle: true,
        actions: [
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
class _ReaderScroll extends StatefulWidget {
  final _LoadedChapter initialChapter;
  final bool continuousReading;
  final String? prevLabel;
  final String? nextLabel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final Future<_LoadedChapter?> Function(int book, int chapter) loadChapterAfter;
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
    required this.selectedVerseId,
    required this.onVerseTap,
    required this.onVerseLongPress,
  });

  @override
  State<_ReaderScroll> createState() => _ReaderScrollState();
}

class _ReaderScrollState extends State<_ReaderScroll> {
  final ScrollController _scrollController = ScrollController();
  late final List<_LoadedChapter> _chapters = [widget.initialChapter];
  bool _loadingNext = false;
  bool _reachedEnd = false;

  @override
  void initState() {
    super.initState();
    if (widget.continuousReading) {
      _scrollController.addListener(_maybeLoadNext);
      // A short chapter may not fill the viewport, leaving nothing to
      // scroll — check once after the first layout.
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadNext());
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
      }
      _loadingNext = false;
    });
    // The appended chapter may still not fill the viewport (short chapters).
    if (next != null && next.verses.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadNext());
    }
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
          controller: _scrollController,
          children: [
            for (var i = 0; i < _chapters.length; i++) ...[
              const SizedBox(height: 16),
              Center(
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
