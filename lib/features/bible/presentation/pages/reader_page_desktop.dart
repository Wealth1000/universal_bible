import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_bible/core/providers/translation_repo_provider.dart';
import 'package:universal_bible/core/utils/book_name_utils.dart';
import 'package:universal_bible/core/utils/scripture_format.dart';
import 'package:universal_bible/database/app_database.dart';
import 'package:universal_bible/features/settings/domain/book_name_settings_provider.dart';
import 'package:universal_bible/features/bible/domain/book_info.dart';
import 'package:universal_bible/features/bible/domain/chapter_navigation.dart';
import 'package:universal_bible/features/bible/domain/continuous_reading_provider.dart';
import 'package:universal_bible/features/bible/domain/reader_provider.dart';
import 'dart:convert';
import '../../../../core/providers/database_provider.dart';

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

// --- Reader Page ---
class ReaderPageDesktop extends ConsumerStatefulWidget {
  const ReaderPageDesktop({super.key});

  @override
  ConsumerState<ReaderPageDesktop> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPageDesktop> {
  List<BookInfo>? _books;
  bool _isLoading = true;
  bool _selectionFabVisible = false;
  String _selectedText = '';

  // Cache the verses future so unrelated setState calls (selection FAB,
  // verse taps) don't recreate it — recreating it makes FutureBuilder
  // re-enter the waiting state, which flickers the reader and destroys
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
      // Format at display time so name fixes apply without re-importing
      // the translation (bookDisplayNamesJson may be stale or missing).
      final displayName =
          formatBookName(name, preserveOriginal: preserveOriginal);
      final counts = bookChapters[number] ?? {};
      books.add(
        BookInfo(
          number: number,
          name: displayName,
          chapterCounts: counts,
        ),
      );
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
    });
  }

  void _goTo(ChapterRef target) {
    ref.read(currentBookProvider.notifier).set(target.book);
    ref.read(currentChapterProvider.notifier).set(target.chapter);
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

  @override
  Widget build(BuildContext context) {
    // Rebuild book names when the "preserve original names" toggle changes.
    ref.listen(preserveOriginalBookNamesProvider, (prev, next) {
      if (prev != next) _loadBooks();
    });

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final primaryColor = isDark ? colorScheme.primary : const Color(0xFF2E434C);
    final onSurfaceVariant = colorScheme.onSurfaceVariant;
    final surfaceColor = theme.scaffoldBackgroundColor;

    final translationId = ref.watch(currentTranslationProvider);
    final book = ref.watch(currentBookProvider);
    final chapter = ref.watch(currentChapterProvider);
    final continuousReading = ref.watch(continuousReadingProvider);

    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (_books == null || _books!.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.translate, size: 48, color: onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'No translations installed.',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: onSurfaceVariant,
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
    final currentChapter =
        chapter ?? (chapterKeys.isNotEmpty ? chapterKeys.first : 1);
    final currentBook = currentBookInfo.number;

    final prevRef = prevChapterRef(_books!, currentBook, currentChapter);
    final nextRef = nextChapterRef(_books!, currentBook, currentChapter);

    final versesFuture = _ensureVersesFuture(translationId, book, chapter);

    return Scaffold(
      backgroundColor: surfaceColor,
      body: Column(
        children: [
          // Top Bar
          _TopBar(
            bookName: bookName,
            chapter: currentChapter,
            books: _books!,
            chapterKeys: chapterKeys,
            translationId: translationId,
            continuousReading: continuousReading,
            onContinuousReadingChanged: (value) {
              ref.read(continuousReadingProvider.notifier).set(value);
            },
            onBookChanged: (newBook) {
              final firstChapter = newBook.chapterCounts.keys.isNotEmpty
                  ? (newBook.chapterCounts.keys.toList()..sort()).first
                  : 1;
              _goTo(ChapterRef(newBook.number, firstChapter));
            },
            onChapterChanged: (newChapter) {
              ref.read(currentChapterProvider.notifier).set(newChapter);
            },
            onTranslationTap: () {
              // TODO: Show translation switcher
            },
          ),
          // Scripture Content
          Expanded(
            child: FutureBuilder<List<Verse>>(
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
                return _ReaderContent(
                  // Reset loaded chapters and scroll when the user
                  // navigates or toggles continuous mode.
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
                  onTextSelected: (text) {
                    // Only rebuild when the state actually changes —
                    // rebuilding during a selection drag causes churn.
                    final visible = text.isNotEmpty;
                    if (visible == _selectionFabVisible &&
                        text == _selectedText) {
                      return;
                    }
                    setState(() {
                      if (visible) {
                        _selectedText = text;
                      }
                      _selectionFabVisible = visible;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectionFabVisible
          ? FloatingActionButton.extended(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Copied: $_selectedText')),
                );
                setState(() {
                  _selectionFabVisible = false;
                });
              },
              label: Row(
                children: [
                  const Icon(Icons.edit),
                  const SizedBox(width: 8),
                  const Text('Add Note'),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 20, color: Colors.white30),
                  const SizedBox(width: 8),
                  const Icon(Icons.share),
                ],
              ),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}

// --- Top Bar Widget ---
class _TopBar extends StatelessWidget {
  final String bookName;
  final int chapter;
  final List<BookInfo> books;
  final List<int> chapterKeys;
  final String? translationId;
  final bool continuousReading;
  final ValueChanged<bool> onContinuousReadingChanged;
  final Function(BookInfo) onBookChanged;
  final Function(int) onChapterChanged;
  final VoidCallback onTranslationTap;

  const _TopBar({
    required this.bookName,
    required this.chapter,
    required this.books,
    required this.chapterKeys,
    this.translationId,
    required this.continuousReading,
    required this.onContinuousReadingChanged,
    required this.onBookChanged,
    required this.onChapterChanged,
    required this.onTranslationTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? colorScheme.primary : const Color(0xFF2E434C);
    final surfaceColor = colorScheme.surface;

    // Use the actual translation ID or a fallback
    final displayTranslation = translationId?.toUpperCase() ?? 'KJV';

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              DropdownButton<BookInfo>(
                value: books.firstWhere(
                  (b) => b.name == bookName,
                  orElse: () => books.first,
                ),
                items: books.map((book) {
                  return DropdownMenuItem<BookInfo>(
                    value: book,
                    child: Text(book.name),
                  );
                }).toList(),
                onChanged: (newBook) {
                  if (newBook != null) {
                    onBookChanged(newBook);
                  }
                },
                underline: const SizedBox.shrink(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
                icon: const Icon(Icons.expand_more),
              ),
              const SizedBox(width: 16),
              DropdownButton<int>(
                value: chapter,
                items: chapterKeys.map((ch) {
                  return DropdownMenuItem<int>(
                    value: ch,
                    child: Text('Chapter $ch'),
                  );
                }).toList(),
                onChanged: (newChapter) {
                  if (newChapter != null) {
                    onChapterChanged(newChapter);
                  }
                },
                underline: const SizedBox.shrink(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
                icon: const Icon(Icons.expand_more),
              ),
            ],
          ),
          Row(
            children: [
              TextButton(
                onPressed: onTranslationTap,
                style: TextButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Text(displayTranslation),
                    const SizedBox(width: 4),
                    const Icon(Icons.translate, size: 18),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
                tooltip: 'Reader options',
                onSelected: (value) {
                  if (value == 'continuous') {
                    onContinuousReadingChanged(!continuousReading);
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
        ],
      ),
    );
  }
}

// --- Reader Content Widget ---
class _ReaderContent extends StatefulWidget {
  final _LoadedChapter initialChapter;
  final bool continuousReading;
  final String? prevLabel;
  final String? nextLabel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final Future<_LoadedChapter?> Function(int book, int chapter) loadChapterAfter;
  final Function(String) onTextSelected;

  const _ReaderContent({
    super.key,
    required this.initialChapter,
    required this.continuousReading,
    required this.prevLabel,
    required this.nextLabel,
    required this.onPrev,
    required this.onNext,
    required this.loadChapterAfter,
    required this.onTextSelected,
  });

  @override
  State<_ReaderContent> createState() => _ReaderContentState();
}

class _ReaderContentState extends State<_ReaderContent> {
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
    if (_scrollController.position.extentAfter > 800) return;

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
    //final theme = Theme.of(context);
    //final colorScheme = theme.colorScheme;
   // final onSurfaceVariant = colorScheme.onSurfaceVariant;

    return Scrollbar(
      controller: _scrollController,
      child: SelectionArea(
        // One selection region for the whole chapter so selection flows
        // continuously across verses instead of per-verse islands.
        onSelectionChanged: (selection) {
          widget.onTextSelected(selection?.plainText ?? '');
        },
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          children: [
            for (var i = 0; i < _chapters.length; i++) ...[
              if (i > 0) const SizedBox(height: 48),
              _ChapterHeader(chapter: _chapters[i]),
              const SizedBox(height: 48),
              ..._chapters[i].verses.map((verse) {
                return _VerseTile(
                  verseNumber: verse.verse,
                  text: verse.verseText,
                );
              }),
            ],
            const SizedBox(height: 48),
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
              _ChapterNavButtons(
                prevLabel: widget.prevLabel,
                nextLabel: widget.nextLabel,
                onPrev: widget.onPrev,
                onNext: widget.onNext,
              ),
            const SizedBox(height: 64),
          ],
        ),
      ),
    );
  }
}

// --- Chapter Header (book name + chapter number) ---
class _ChapterHeader extends StatelessWidget {
  final _LoadedChapter chapter;

  const _ChapterHeader({required this.chapter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        children: [
          Text(
            chapter.bookName,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chapter ${chapter.chapter}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Previous / Next chapter buttons ---
class _ChapterNavButtons extends StatelessWidget {
  final String? prevLabel;
  final String? nextLabel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _ChapterNavButtons({
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

    ButtonStyle style = TextButton.styleFrom(
      side: BorderSide(color: colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (onPrev != null) ...[
          TextButton(
            onPressed: onPrev,
            style: style,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, size: 18, color: onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  prevLabel!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
        if (onNext != null)
          TextButton(
            onPressed: onNext,
            style: style,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nextLabel!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 18, color: onSurfaceVariant),
              ],
            ),
          ),
      ],
    );
  }
}

// --- Individual Verse Tile ---
class _VerseTile extends StatefulWidget {
  final int verseNumber;
  final String text;

  const _VerseTile({
    required this.verseNumber,
    required this.text,
  });

  @override
  State<_VerseTile> createState() => _VerseTileState();
}

class _VerseTileState extends State<_VerseTile> {
  bool _isSelected = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;

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
      onTap: () {
        setState(() {
          _isSelected = !_isSelected;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: _isSelected
              ? (isDark ? Colors.grey.shade800 : const Color(0xFFFFFDE7))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '${widget.verseNumber}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onSurfaceVariant.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text.rich(TextSpan(children: spans)),
            ),
          ],
        ),
      ),
    );
  }
}
