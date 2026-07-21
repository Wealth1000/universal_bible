import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_bible/core/providers/translation_repo_provider.dart';
import 'package:universal_bible/core/utils/book_name_utils.dart';
import 'package:universal_bible/core/utils/scripture_format.dart';
import 'package:universal_bible/database/app_database.dart'
    hide ReadingPosition;
import 'package:universal_bible/features/settings/domain/book_name_settings_provider.dart';
import 'package:universal_bible/features/bible/domain/book_info.dart';
import 'package:universal_bible/features/bible/domain/chapter_navigation.dart';
import 'package:universal_bible/features/bible/domain/continuous_reading_provider.dart';
import 'package:universal_bible/features/bible/domain/reader_provider.dart';
import 'package:universal_bible/features/bible/presentation/widgets/translation_grid.dart';
import 'package:universal_bible/features/bible/presentation/widgets/verse_action_panel.dart';
import 'package:uuid/uuid.dart';
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
  // Full name of the active translation, for the pill's semantic label.
  String? _translationName;
  bool _isLoading = true;
  bool _selectionFabVisible = false;
  String _selectedText = '';
  // Anchor for the translation pill's grid dropdown.
  final GlobalKey _translationPillKey = GlobalKey();

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
      _translationName = trans.name;
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
      // After a translation switch the in-session book/chapter may not
      // exist in the new book map — clamp (don't reset) so the reader
      // shows real content. Mirrors mobile's _updateChapterCounts.
      if (currentBook != null && books.isNotEmpty) {
        final bookExists = books.any((b) => b.number == currentBook);
        final effectiveBookNum = bookExists ? currentBook : books.first.number;
        if (!bookExists) {
          ref.read(currentBookProvider.notifier).set(effectiveBookNum);
        }
        final bookInfo =
            books.firstWhere((b) => b.number == effectiveBookNum);
        final chapterNow = ref.read(currentChapterProvider);
        if (chapterNow != null &&
            !bookInfo.chapterCounts.containsKey(chapterNow)) {
          final firstChapter = bookInfo.chapterCounts.keys.isNotEmpty
              ? (bookInfo.chapterCounts.keys.toList()..sort()).first
              : 1;
          ref.read(currentChapterProvider.notifier).set(firstChapter);
          _persistPosition(effectiveBookNum, firstChapter);
        }
      }
    });
  }

  void _goTo(ChapterRef target) {
    ref.read(currentBookProvider.notifier).set(target.book);
    ref.read(currentChapterProvider.notifier).set(target.chapter);
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

  @override
  Widget build(BuildContext context) {
    // Rebuild book names when the "preserve original names" toggle changes.
    ref.listen(preserveOriginalBookNamesProvider, (prev, next) {
      if (prev != next) _loadBooks();
    });
    // Reload the book map when the translation changes (pill switch) —
    // book names / chapter counts differ per translation. Book & chapter
    // providers are non-null here, so _loadBooks leaves them untouched
    // and the reader stays at the same position.
    ref.listen(currentTranslationProvider, (prev, next) {
      if (prev != null && next != null && prev != next) _loadBooks();
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

    // Read the visible chapter for the AppBar label (from scroll-follow).
    final visibleChapter = ref.watch(visibleChapterProvider) ?? chapter;

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
            chapter: currentChapter,        // for dropdown value
            displayChapter: visibleChapter, // for the label
            books: _books!,
            chapterKeys: chapterKeys,
            translationId: translationId,
            translationName: _translationName,
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
              _persistPosition(currentBook, newChapter);
            },
            onTranslationTap: () {
              showTranslationGridDropdown(
                context,
                anchorKey: _translationPillKey,
              );
            },
            translationPillKey: _translationPillKey,
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
                  loadChapterBefore: _loadChapterBefore,
                  // Verse taps (not mouse text-selection) drive the
                  // action overlay: text is the joined selected verses,
                  // empty when the last verse is deselected.
                  onVersesSelected: (text) {
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _selectionFabVisible
          ? VerseActionPanel(
              onHighlight: _applyHighlight,
              onCustomHighlight: () async {
                final color = await showHighlightColorPickerDialog(context);
                if (color != null) {
                  await _applyHighlight(color);
                }
              },
              onBookmark: _bookmarkSelection,
              onNote: _noteSelection,
              onCopy: () => _copySelection('Copied to clipboard'),
              // No system share sheet on Linux desktop without a plugin
              // (pub is frozen) — Share copies with a distinct toast.
              onShare: () => _copySelection('Copied for sharing'),
              onCompare: () {
                // TODO(§6): open the compare panel.
                _toast('Compare is coming soon');
              },
              onClose: _clearSelection,
            )
          : null,
    );
  }

  // --- §5 selection actions ---

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearSelection() {
    ref.read(selectedVersesProvider.notifier).clear();
    setState(() {
      _selectionFabVisible = false;
      _selectedText = '';
    });
  }

  List<VerseRef> _sortedSelection() {
    final refs = ref.read(selectedVersesProvider).toList()
      ..sort((a, b) {
        if (a.book != b.book) return a.book - b.book;
        if (a.chapter != b.chapter) return a.chapter - b.chapter;
        return a.verse - b.verse;
      });
    return refs;
  }

  /// Applies [color] to the selection. If every selected verse already has
  /// exactly this color, the highlight is removed instead (toggle-off);
  /// otherwise existing highlights are replaced (one color per verse).
  Future<void> _applyHighlight(Color color) async {
    final translationId = ref.read(currentTranslationProvider);
    final refs = _sortedSelection();
    if (translationId == null || refs.isEmpty) return;
    final db = ref.read(databaseProvider);
    final hex = highlightColorToHex(color);

    var allAlreadyThisColor = true;
    for (final v in refs) {
      final existing = await db.getHighlightsForVerse(
        translationId,
        v.book,
        v.chapter,
        v.verse,
      );
      if (existing.isEmpty || existing.any((h) => h.color != hex)) {
        allAlreadyThisColor = false;
        break;
      }
    }

    for (final v in refs) {
      await db.deleteHighlightsForVerse(
        translationId,
        v.book,
        v.chapter,
        v.verse,
      );
      if (!allAlreadyThisColor) {
        await db.insertHighlight(
          HighlightsCompanion.insert(
            id: const Uuid().v4(),
            translationId: translationId,
            bookNumber: v.book,
            chapter: v.chapter,
            verse: v.verse,
            color: hex,
            createdAt: DateTime.now(),
          ),
        );
      }
    }

    ref.read(highlightsVersionProvider.notifier).bump();
    _toast(
      allAlreadyThisColor
          ? 'Highlight removed from ${refs.length} verse(s)'
          : 'Highlighted ${refs.length} verse(s)',
    );
  }

  Future<void> _bookmarkSelection() async {
    final translationId = ref.read(currentTranslationProvider);
    final refs = _sortedSelection();
    if (translationId == null || refs.isEmpty) return;
    final db = ref.read(databaseProvider);
    for (final v in refs) {
      await db.insertBookmark(
        BookmarksCompanion.insert(
          id: const Uuid().v4(),
          translationId: translationId,
          bookNumber: v.book,
          chapter: v.chapter,
          verse: v.verse,
          createdAt: DateTime.now(),
        ),
      );
    }
    _toast('Bookmarked ${refs.length} verse(s)');
  }

  Future<void> _noteSelection() async {
    final translationId = ref.read(currentTranslationProvider);
    final refs = _sortedSelection();
    if (translationId == null || refs.isEmpty) return;

    final controller = TextEditingController();
    final content = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add note'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 6,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: 'Write your note…',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (content == null || content.isEmpty) return;

    // One row per selected verse, same content (v1).
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    for (final v in refs) {
      await db.insertNote(
        NotesCompanion.insert(
          id: const Uuid().v4(),
          translationId: translationId,
          bookNumber: v.book,
          chapter: v.chapter,
          verse: v.verse,
          content: content,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    _toast('Note saved for ${refs.length} verse(s)');
  }

  void _copySelection(String toast) {
    if (_selectedText.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _selectedText));
    _toast(toast);
  }
}

// --- Top Bar Widget ---
class _TopBar extends StatelessWidget {
  final String bookName;
  final int chapter;            // value for chapter dropdown
  final int? displayChapter;     // displayed in the label (can follow scroll)
  final List<BookInfo> books;
  final List<int> chapterKeys;
  final String? translationId;
  final String? translationName;
  final bool continuousReading;
  final ValueChanged<bool> onContinuousReadingChanged;
  final Function(BookInfo) onBookChanged;
  final Function(int) onChapterChanged;
  final VoidCallback onTranslationTap;
  final GlobalKey? translationPillKey;

  const _TopBar({
    required this.bookName,
    required this.chapter,
    required this.displayChapter,
    required this.books,
    required this.chapterKeys,
    this.translationId,
    this.translationName,
    required this.continuousReading,
    required this.onContinuousReadingChanged,
    required this.onBookChanged,
    required this.onChapterChanged,
    required this.onTranslationTap,
    this.translationPillKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? colorScheme.primary : const Color(0xFF2E434C);
    final surfaceColor = colorScheme.surface;
    final chapterToShow = displayChapter ?? chapter;

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
                // Show whichever chapter is currently visible on screen.
                // Fall back to the navigation chapter if the visible one is
                // not in the current book's list (e.g. cross-book scroll).
                value: chapterKeys.contains(chapterToShow) ? chapterToShow : chapter,
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
              // Chapter label is shown separately above the dropdown; it's
              // already displayed in the dropdown's value – we can keep it
              // as is, but for clarity we'll also show a static label.
              // Padding(
              //   padding: const EdgeInsets.symmetric(horizontal: 8.0),
              //   child: Text(
              //     'Chapter $chapterToShow',
              //     style: theme.textTheme.titleMedium?.copyWith(
              //       fontWeight: FontWeight.w700,
              //       color: primaryColor,
              //     ),
              //   ),
              // ),
              // Search shortcut (§7): secondary entry point to the Search
              // screen, alongside the sidebar item.
              IconButton(
                icon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                tooltip: 'Search',
                onPressed: () => context.go('/search'),
              ),
              const SizedBox(width: 8),
              // Translation pill (§2): opens the grid dropdown.
              Semantics(
                button: true,
                label:
                    'Active translation: ${translationName ?? displayTranslation}. Tap to switch.',
                child: TextButton(
                  key: translationPillKey,
                  onPressed: onTranslationTap,
                  style: TextButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    children: [
                      Text(displayTranslation),
                      const SizedBox(width: 4),
                      const Icon(Icons.expand_more, size: 18),
                    ],
                  ),
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
class _ReaderContent extends ConsumerStatefulWidget {
  final _LoadedChapter initialChapter;
  final bool continuousReading;
  final String? prevLabel;
  final String? nextLabel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final Future<_LoadedChapter?> Function(int book, int chapter) loadChapterAfter;
  final Future<_LoadedChapter?> Function(int book, int chapter) loadChapterBefore;
  final Function(String) onVersesSelected;

  const _ReaderContent({
    super.key,
    required this.initialChapter,
    required this.continuousReading,
    required this.prevLabel,
    required this.nextLabel,
    required this.onPrev,
    required this.onNext,
    required this.loadChapterAfter,
    required this.loadChapterBefore,
    required this.onVersesSelected,
  });

  @override
  ConsumerState<_ReaderContent> createState() => _ReaderContentState();
}

class _ReaderContentState extends ConsumerState<_ReaderContent> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollKey = GlobalKey();
  late final List<_LoadedChapter> _chapters = [widget.initialChapter];
  final List<GlobalKey> _chapterHeaderKeys = [GlobalKey()];
  bool _loadingNext = false;
  bool _reachedEnd = false;
  bool _loadingPrev = false;
  bool _reachedStart = false;

  void _toggleVerse(_LoadedChapter chapter, Verse verse) {
    // Selection lives in selectedVersesProvider (shared with the §5 action
    // panel and the future §6 compare panel). Verse taps — not mouse
    // text-selection — drive it.
    ref
        .read(selectedVersesProvider.notifier)
        .toggle(VerseRef(chapter.book, chapter.chapter, verse.verse));
    // Report the selected verses' plain text, in reading order.
    final selected = ref.read(selectedVersesProvider);
    final parts = <String>[];
    for (final ch in _chapters) {
      for (final v in ch.verses) {
        if (selected.contains(VerseRef(ch.book, ch.chapter, v.verse))) {
          parts.add(
            '${ch.bookName} ${ch.chapter}:${v.verse} '
            '${normalizeResolvedScriptureText(v.verseText)}',
          );
        }
      }
    }
    widget.onVersesSelected(parts.join('\n'));
  }

  // Persisted highlights for the loaded chapters, keyed by verse ref.
  final Map<VerseRef, Color> _highlightsByVerse = {};

  // Cooldown timer to prevent rapid successive loading.
  Timer? _loadCooldownTimer;

  /// (Re)loads highlights for every loaded chapter into [_highlightsByVerse].
  Future<void> _reloadHighlights() async {
    final translationId = ref.read(currentTranslationProvider);
    if (translationId == null) return;
    final db = ref.read(databaseProvider);
    final loaded = <VerseRef, Color>{};
    for (final ch in List<_LoadedChapter>.of(_chapters)) {
      final rows =
          await db.getHighlightsForChapter(translationId, ch.book, ch.chapter);
      for (final h in rows) {
        final color = highlightColorFromHex(h.color);
        if (color != null) {
          loaded[VerseRef(h.bookNumber, h.chapter, h.verse)] = color;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _highlightsByVerse
        ..clear()
        ..addAll(loaded);
    });
  }

  @override
  void initState() {
    super.initState();
    // Set the visible chapter after the first frame to avoid modifying provider during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(visibleChapterProvider.notifier).set(widget.initialChapter.chapter);
        // Content recreation (navigation, translation switch) starts a
        // fresh selection — mirrors the pre-provider local-state behavior.
        ref.read(selectedVersesProvider.notifier).clear();
        widget.onVersesSelected('');
      }
    });

    // Always track which chapter header is visually centred.
    _scrollController.addListener(_updateVisibleChapter);

    // Load persisted highlights for the initial chapter.
    _reloadHighlights();

    if (widget.continuousReading) {
      _scrollController.addListener(_maybeLoadNext);
      _scrollController.addListener(_maybeLoadPrev);
      // Prefetch the next chapter once after layout if we have room.
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadNext());
    }
  }

  @override
  void dispose() {
    _loadCooldownTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Updates [visibleChapterProvider] to the chapter whose header was most
  /// recently above the vertical midpoint of the viewport.
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

  Future<void> _maybeLoadNext() async {
    if (_loadingNext || _reachedEnd || !mounted) return;
    if (!_scrollController.hasClients) return;
    // Increase threshold: only load when there's more than 1500px of scroll
    // space left before the end of the current content.
    if (_scrollController.position.extentAfter > 1500) return;

    _loadingNext = true;
    final last = _chapters.last;
    final next = await widget.loadChapterAfter(last.book, last.chapter);
    if (!mounted) {
      _loadingNext = false;
      return;
    }
    setState(() {
      if (next == null || next.verses.isEmpty) {
        _reachedEnd = true;
      } else {
        _chapters.add(next);
        _chapterHeaderKeys.add(GlobalKey());
      }
      _loadingNext = false;
    });
    if (next != null && next.verses.isNotEmpty) {
      // Pick up any highlights in the newly loaded chapter.
      _reloadHighlights();
    }

    // If we loaded a chapter, schedule another check after a cooldown.
    if (next != null && next.verses.isNotEmpty) {
      _loadCooldownTimer?.cancel();
      _loadCooldownTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          _maybeLoadNext();
        }
      });
    }
  }

  Future<void> _maybeLoadPrev() async {
    if (_loadingPrev || _reachedStart || !mounted) return;
    if (!_scrollController.hasClients) return;
    // Only load when scrolled within 100px of the top.
    if (_scrollController.position.pixels > 100) return;

    _loadingPrev = true;
    final first = _chapters.first;
    final prev = await widget.loadChapterBefore(first.book, first.chapter);
    if (!mounted) {
      _loadingPrev = false;
      return;
    }
    if (prev == null || prev.verses.isEmpty) {
      setState(() {
        _reachedStart = true;
        _loadingPrev = false;
      });
      return;
    }

    // Capture current max extent before insertion.
    final oldMaxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;

    setState(() {
      _chapters.insert(0, prev);
      _chapterHeaderKeys.insert(0, GlobalKey());
    });
    // Pick up any highlights in the newly loaded chapter.
    _reloadHighlights();

    // After layout, jump forward by the height of the inserted content so
    // the viewport still shows the same verses.
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
    final selectedVerses = ref.watch(selectedVersesProvider);
    // Re-fetch highlights after any highlight write (§5 action panel).
    ref.listen(highlightsVersionProvider, (prev, next) => _reloadHighlights());
    // Removed Scrollbar wrapper as requested.
    // SelectionArea keeps mouse text-selection available for copying, but
    // it no longer drives the action overlay — verse taps do.
    return SelectionArea(
      child: ListView(
        key: _scrollKey,
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        children: [
          for (var i = 0; i < _chapters.length; i++) ...[
            if (i > 0) const SizedBox(height: 48),
            _ChapterHeader(key: _chapterHeaderKeys[i], chapter: _chapters[i]),
            const SizedBox(height: 48),
            ..._chapters[i].verses.map((verse) {
              final vRef = VerseRef(
                _chapters[i].book,
                _chapters[i].chapter,
                verse.verse,
              );
              return _VerseTile(
                verseNumber: verse.verse,
                text: verse.verseText,
                selected: selectedVerses.contains(vRef),
                highlightColor: _highlightsByVerse[vRef],
                onTap: () => _toggleVerse(_chapters[i], verse),
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
    );
  }
}

// --- Chapter Header (book name + chapter number) ---
class _ChapterHeader extends StatelessWidget {
  final _LoadedChapter chapter;

  const _ChapterHeader({super.key, required this.chapter});

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
class _VerseTile extends StatelessWidget {
  final int verseNumber;
  final String text;
  final bool selected;
  final Color? highlightColor;
  final VoidCallback onTap;

  const _VerseTile({
    required this.verseNumber,
    required this.text,
    required this.selected,
    this.highlightColor,
    required this.onTap,
  });

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
      text,
      preserveWordsOfChrist: true,
    );
    final spans = buildScriptureSpans(
      normalized,
      baseStyle: baseStyle,
      wordsOfChristColor: wordsOfChristColorFor(theme.brightness),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          // Selection tint wins over a persisted highlight; a selected
          // highlighted verse keeps its highlight visible via the border.
          color: selected
              ? (isDark ? Colors.grey.shade800 : const Color(0xFFFFFDE7))
              : (highlightColor ?? Colors.transparent),
          border: selected && highlightColor != null
              ? Border.all(color: highlightColor!.withValues(alpha: 1))
              : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '$verseNumber',
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