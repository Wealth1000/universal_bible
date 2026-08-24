import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_bible/core/design/app_tokens.dart';
import 'package:universal_bible/core/providers/reading_settings_provider.dart';
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
import 'package:universal_bible/features/bible/presentation/widgets/chapter_grid.dart';
import 'package:universal_bible/features/bible/presentation/widgets/book_picker.dart';
import 'package:universal_bible/features/bible/presentation/widgets/compare_column.dart';
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
  final GlobalKey _chapterButtonKey = GlobalKey();
  final GlobalKey _bookButtonKey = GlobalKey();

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
    // Default translation (settings) is a fallback only — used when there
    // is no in-session value and no persisted reading position.
    final defaultId = ref.read(defaultTranslationProvider);
    final defaultTransId = translations.any((t) => t.id == defaultId)
        ? defaultId
        : null;
    final transId =
        currentTransId ??
        persistedTransId ??
        defaultTransId ??
        translations.first.id;
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
      final displayName = formatBookName(
        name,
        preserveOriginal: preserveOriginal,
      );
      final counts = bookChapters[number] ?? {};
      books.add(
        BookInfo(number: number, name: displayName, chapterCounts: counts),
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
        final bookInfo = books.firstWhere((b) => b.number == effectiveBookNum);
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
    ref
        .read(readingPositionProvider.notifier)
        .save(
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
    final colorScheme = theme.colorScheme;

    final primaryColor = colorScheme.primary;
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

    // §6: split view — reader left (~60%), comparison right (~40%). Shown
    // while Compare is open AND the selection is non-empty (deselecting
    // everything closes it). Selection updates flow into the pane live.
    final selectedVerses = ref.watch(selectedVersesProvider);
    final compareVisible =
        ref.watch(compareOpenProvider) && selectedVerses.isNotEmpty;

    final readerColumn = Column(
      children: [
        // Top Bar
        _TopBar(
          bookName: bookName,
          chapter: currentChapter, // for dropdown value
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
          onChapterTap: () {
            showChapterGridDropdown(
              context,
              chapterKeys: chapterKeys,
              currentChapter: currentChapter,
              anchorKey: _chapterButtonKey,
              onSelected: (newChapter) {
                ref.read(currentChapterProvider.notifier).set(newChapter);
                _persistPosition(currentBook, newChapter);
              },
            );
          },
          chapterButtonKey: _chapterButtonKey,
          onBookTap: () {
            showBookPickerDropdown(
              context,
              books: _books!,
              currentBookName: bookName,
              anchorKey: _bookButtonKey,
              onSelected: (newBook) {
                final firstChapter = newBook.chapterCounts.keys.isNotEmpty
                    ? (newBook.chapterCounts.keys.toList()..sort()).first
                    : 1;
                _goTo(ChapterRef(newBook.number, firstChapter));
              },
            );
          },
          bookButtonKey: _bookButtonKey,
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
    );

    return Scaffold(
      backgroundColor: surfaceColor,
      // The reader ALWAYS lives at the same position inside this Row —
      // only the compare pane is conditionally present. Restructuring the
      // tree (Column ↔ Row) would recreate _ReaderContent, whose
      // fresh-content callback clears the selection and closes compare
      // (the "compare instantly closes" bug).
      body: Row(
        children: [
          Expanded(flex: 6, child: readerColumn),
          if (compareVisible) ...[
            Container(width: 1, color: colorScheme.outlineVariant),
            Expanded(
              flex: 4,
              child: ColoredBox(
                // Chrome surface so the pane reads as chrome next to the
                // paper reader (UI_OVERHAUL §3.2).
                color: colorScheme.surfaceContainerLow,
                child: CompareColumn(
                  refs: _sortedSelection(),
                  bookNameFor: (bookNum) => _books!
                      .firstWhere(
                        (b) => b.number == bookNum,
                        orElse: () => _books!.first,
                      )
                      .name,
                  onClose: () =>
                      ref.read(compareOpenProvider.notifier).set(false),
                  onExpand: () => context.push('/compare'),
                ),
              ),
            ),
          ],
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
                // §6: open the split-view compare pane (live-updating).
                ref.read(compareOpenProvider.notifier).set(true);
              },
              onClose: _clearSelection,
            )
          : null,
    );
  }

  // --- §5 selection actions ---

  /// Brief confirmation for actions whose effect is NOT visible in the
  /// reader (bookmark, note, copy/share). Visible effects (highlights)
  /// get no toast — it would just cover the action panel.
  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          width: 360,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _clearSelection() {
    ref.read(selectedVersesProvider.notifier).clear();
    // A cleared selection also ends the compare session — otherwise the
    // pane would surprisingly reappear on the next verse tap.
    ref.read(compareOpenProvider.notifier).set(false);
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
    // No toast: the result is immediately visible on the verses themselves,
    // and a snackbar would cover the action panel.
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
  final int chapter; // value for chapter dropdown
  final int? displayChapter; // displayed in the label (can follow scroll)
  final List<BookInfo> books;
  final List<int> chapterKeys;
  final String? translationId;
  final String? translationName;
  final bool continuousReading;
  final ValueChanged<bool> onContinuousReadingChanged;
  final Function(BookInfo) onBookChanged;
  final VoidCallback onChapterTap;
  final GlobalKey? chapterButtonKey;
  final VoidCallback onBookTap;
  final GlobalKey? bookButtonKey;
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
    required this.onChapterTap,
    this.chapterButtonKey,
    required this.onBookTap,
    this.bookButtonKey,
    required this.onTranslationTap,
    this.translationPillKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chapterToShow = displayChapter ?? chapter;

    // Use the actual translation ID or a fallback
    final displayTranslation = translationId?.toUpperCase() ?? 'KJV';

    // Quiet chrome bar (UI_OVERHAUL §3.2): chrome surface, no shadow, no
    // border — the paper/chrome shift is the separation.
    return Container(
      height: AppLayout.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
      color: colorScheme.surfaceContainerLow,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Book picker: opens the book picker dropdown.
              Semantics(
                button: true,
                label: 'Book $bookName. Tap to switch.',
                child: InkWell(
                  key: bookButtonKey,
                  onTap: onBookTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: AppSpacing.s8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          bookName,
                          style: AppTypography.uiLabel.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Icon(
                          Icons.expand_more,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              // Chapter picker: opens the number grid dropdown (§2 pattern).
              // The label keeps the "Chapter N" wording; the grid shows
              // whichever chapter is currently visible on screen, falling
              // back to the navigation chapter across book boundaries.
              Semantics(
                button: true,
                label:
                    'Chapter ${chapterKeys.contains(chapterToShow) ? chapterToShow : chapter}. Tap to switch.',
                child: InkWell(
                  key: chapterButtonKey,
                  onTap: onChapterTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: AppSpacing.s8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Chapter ${chapterKeys.contains(chapterToShow) ? chapterToShow : chapter}',
                          style: AppTypography.uiLabel.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Icon(
                          Icons.expand_more,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Search shortcut (§7): secondary entry point to the Search
              // screen, alongside the sidebar item.
              IconButton(
                icon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                tooltip: 'Search',
                onPressed: () => context.go('/search'),
              ),
              const SizedBox(width: AppSpacing.s8),
              // Translation pill (§2): outlined, quiet; abbreviation in ink.
              Semantics(
                button: true,
                label:
                    'Active translation: ${translationName ?? displayTranslation}. Tap to switch.',
                child: OutlinedButton(
                  key: translationPillKey,
                  onPressed: onTranslationTap,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colorScheme.outlineVariant),
                    foregroundColor: colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s8,
                    ),
                    textStyle: AppTypography.scriptureRef,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(displayTranslation),
                      const SizedBox(width: AppSpacing.s4),
                      const Icon(Icons.expand_more, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: colorScheme.onSurfaceVariant,
                ),
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
  final Future<_LoadedChapter?> Function(int book, int chapter)
  loadChapterAfter;
  final Future<_LoadedChapter?> Function(int book, int chapter)
  loadChapterBefore;
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
  // Sliver anchor for the center-anchored CustomScrollView. Chapters after
  // (and including) [_centerIndex] render in the forward sliver keyed by
  // [_centerKey]; chapters before it render in the reverse sliver above.
  // Prepending increments [_centerIndex] so the anchor stays pinned to the
  // same visual chapter and upward loading never shifts the viewport.
  final GlobalKey _centerKey = GlobalKey();
  int _centerIndex = 0;
  late final List<_LoadedChapter> _chapters = [widget.initialChapter];
  final List<GlobalKey> _chapterHeaderKeys = [GlobalKey()];
  // One key per rendered verse so keyboard stepping can measure where verses
  // sit. Keyed by VerseRef, not by list index: continuous mode prepends
  // chapters, which would shift indices out from under the keys.
  final Map<VerseRef, GlobalKey> _verseKeys = {};
  // Scroll offset a keyboard step is animating toward, so a second press
  // lands on the verse after the one in flight instead of re-aiming at it.
  // Null when no keyboard step is running.
  double? _keyStepTarget;
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
      final rows = await db.getHighlightsForChapter(
        translationId,
        ch.book,
        ch.chapter,
      );
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
        ref
            .read(visibleChapterProvider.notifier)
            .set(widget.initialChapter.chapter);
        // Content recreation (navigation, translation switch) starts a
        // fresh selection — mirrors the pre-provider local-state behavior.
        ref.read(selectedVersesProvider.notifier).clear();
        ref.read(compareOpenProvider.notifier).set(false);
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

      final topInViewport = listBox
          .globalToLocal(headerBox.localToGlobal(Offset.zero))
          .dy;

      if (topInViewport <= halfViewport) {
        ref.read(visibleChapterProvider.notifier).set(_chapters[i].chapter);
        // Persist the centered chapter so the reader reopens here — this
        // covers continuous-mode reading (incl. cross-book drift), which
        // never goes through navigation. Debounced inside the notifier.
        final translationId = ref.read(currentTranslationProvider);
        if (translationId != null) {
          ref
              .read(readingPositionProvider.notifier)
              .save(
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

  /// Prepends the previous chapter once the top of the loaded content is
  /// within reach (continuous mode).
  ///
  /// [ignoreScrollDirection] is for callers that already know the reader is
  /// heading up (keyboard stepping): a programmatic scroll reports no user
  /// scroll direction, so the guard below would never let them through.
  Future<void> _maybeLoadPrev({bool ignoreScrollDirection = false}) async {
    if (_loadingPrev || _reachedStart || !mounted) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Only prepend while the user is actively scrolling UP toward the top.
    // Without this, the same near-top position while scrolling down would
    // prepend the previous chapter — the old teleport bug.
    if (!ignoreScrollDirection &&
        position.userScrollDirection != ScrollDirection.forward) {
      return;
    }
    // ...and only when the top of the loaded content is within reach — a
    // pre-load buffer mirroring _maybeLoadNext's forward lookahead.
    if (position.extentBefore > 1500) return;

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

    // Prepend into the reverse (above-anchor) sliver. Because that sliver
    // grows away from the fixed center anchor, the viewport does not shift —
    // no jumpTo compensation needed. Bump [_centerIndex] so the anchor stays
    // pinned to the same visual chapter.
    setState(() {
      _chapters.insert(0, prev);
      _chapterHeaderKeys.insert(0, GlobalKey());
      _centerIndex += 1;
    });
    // Pick up any highlights in the newly loaded chapter.
    _reloadHighlights();
    _loadingPrev = false;
  }

  // --- Keyboard verse stepping (Up / Down) ---

  /// Where a stepped-to verse lands: this far below the top of the reading
  /// area. Whatever sits on that line counts as the current verse.
  static const double _verseAnchorInset = AppSpacing.s12;

  /// Moves the reader exactly one verse down ([direction] == 1) or up (-1).
  ///
  /// Verses differ wildly in height, so rather than scroll a fixed number of
  /// pixels this snaps the anchor line onto the next/previous verse (or
  /// chapter title) boundary. Boundaries are measured in scroll-offset space —
  /// `pixels + offsetFromViewportTop` is invariant while scrolling — so
  /// measuring in the middle of an in-flight step is safe.
  void _stepByVerse(int direction) {
    if (!_scrollController.hasClients) return;
    final listCtx = _scrollKey.currentContext;
    if (listCtx == null) return;
    final listBox = listCtx.findRenderObject() as RenderBox?;
    if (listBox == null) return;

    final position = _scrollController.position;
    // Step from where an in-flight step is headed, not from the offset it
    // happens to be passing through.
    final reference = _keyStepTarget ?? position.pixels;
    final anchor = reference + _verseAnchorInset;
    // Boundaries within a hair of the anchor are the one we're already on;
    // ignoring them keeps a press from re-aiming at the current verse.
    const tolerance = 2.0;

    double? target;
    void considerBoundary(GlobalKey key) {
      // Null context = not currently built (an off-screen chapter).
      final ctx = key.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) return;
      final top =
          position.pixels +
          listBox.globalToLocal(box.localToGlobal(Offset.zero)).dy;
      final closer = direction > 0
          ? top > anchor + tolerance && (target == null || top < target!)
          : top < anchor - tolerance && (target == null || top > target!);
      if (closer) target = top;
    }

    // Chapter titles are boundaries too, so crossing into the next chapter
    // stops at its heading instead of scrolling straight past it.
    for (final key in _chapterHeaderKeys) {
      considerBoundary(key);
    }
    for (final key in _verseKeys.values) {
      considerBoundary(key);
    }

    // With no boundary that way we're in the padding past the last built
    // verse (or before the first); a bounded nudge keeps the very top and
    // bottom of the loaded content reachable without a wild jump.
    final destination = target != null
        ? target! - _verseAnchorInset
        : reference + direction * position.viewportDimension * 0.5;
    final clamped = destination.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((clamped - reference).abs() < 0.5) return;

    _keyStepTarget = clamped;
    _scrollController
        .animateTo(
          clamped,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          // A newer step may already own the field.
          if (_keyStepTarget == clamped) _keyStepTarget = null;
        });
  }

  /// Up/Down step the reader one verse; every other key falls through.
  ///
  /// This node sits ABOVE the [SelectionArea] (see [build]) so it stays in the
  /// key-event chain once a click hands focus to the selectable region, and so
  /// it runs before Flutter's default arrow-key scrolling.
  KeyEventResult _handleReaderKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final isDown = event.logicalKey == LogicalKeyboardKey.arrowDown;
    final isUp = event.logicalKey == LogicalKeyboardKey.arrowUp;
    if (!isDown && !isUp) return KeyEventResult.ignored;
    // Modified combos stay with their owners — shift+arrow still extends a
    // text selection inside the SelectionArea.
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    // Pace a held key to one verse per step animation. Auto-repeat fires
    // several times faster than that and would fly down the chapter.
    if (event is KeyRepeatEvent && _keyStepTarget != null) {
      return KeyEventResult.handled;
    }
    if (isUp && widget.continuousReading) {
      // Keyboard scrolling is programmatic, so it reports no user scroll
      // direction and the listener that prepends the previous chapter can
      // never fire for it — ask directly (it self-guards on distance).
      _maybeLoadPrev(ignoreScrollDirection: true);
    }
    _stepByVerse(isDown ? 1 : -1);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final selectedVerses = ref.watch(selectedVersesProvider);
    // Reading settings (settings page) — live-update the verse rendering.
    final fontSize = ref.watch(fontSizeProvider);
    final showVerseNumbers = ref.watch(showVerseNumbersProvider);
    // Re-fetch highlights after any highlight write (§5 action panel).
    ref.listen(highlightsVersionProvider, (prev, next) => _reloadHighlights());

    // Builds one chapter block (leading gap + header + verses). Called lazily
    // by the sliver delegates, so off-screen chapters aren't built. Captures
    // the current reading settings / selection so it re-runs on change.
    Widget buildChapterSlice(int index) {
      final ch = _chapters[index];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.s48),
          _ChapterHeader(key: _chapterHeaderKeys[index], chapter: ch),
          const SizedBox(height: AppSpacing.s48),
          ...ch.verses.map((verse) {
            final vRef = VerseRef(ch.book, ch.chapter, verse.verse);
            return _VerseTile(
              // Lets keyboard stepping measure this verse's position.
              key: _verseKeys.putIfAbsent(vRef, () => GlobalKey()),
              verseNumber: verse.verse,
              text: verse.verseText,
              selected: selectedVerses.contains(vRef),
              highlightColor: _highlightsByVerse[vRef],
              fontSize: fontSize,
              showVerseNumber: showVerseNumbers,
              onTap: () => _toggleVerse(ch, verse),
            );
          }),
        ],
      );
    }

    const horizontalPadding = EdgeInsets.symmetric(horizontal: AppSpacing.s32);

    // Removed Scrollbar wrapper as requested.
    // SelectionArea keeps mouse text-selection available for copying, but
    // it no longer drives the action overlay — verse taps do.
    // Full-width scripture (owner preference — no max-width measure).
    //
    // CustomScrollView with a center anchor pinned to the initially-loaded
    // chapter: chapters appended below and prepended above both grow away
    // from a fixed viewport, so upward loading (see _maybeLoadPrev) never
    // shifts what's on screen.
    //
    // The Focus wraps SelectionArea (not the other way round) so Up/Down
    // reach _handleReaderKey even after a click moves focus into the
    // selectable region — see _handleReaderKey. autofocus means the keys work
    // as soon as the reader opens, without a click first; skipTraversal keeps
    // Tab on the real controls, since this node is only here to catch keys.
    return Focus(
      autofocus: true,
      skipTraversal: true,
      onKeyEvent: _handleReaderKey,
      child: SelectionArea(
        child: CustomScrollView(
          key: _scrollKey,
          controller: _scrollController,
          center: _centerKey,
          slivers: [
            // Above the anchor: previous-chapter loading indicator, else a
            // small top inset. Lives in negative scroll space.
            SliverToBoxAdapter(
              child:
                  (widget.continuousReading && _loadingPrev && !_reachedStart)
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : const SizedBox(height: AppSpacing.s24),
            ),
            // Chapters BEFORE the anchor, nearest-first (this sliver is laid
            // out upward, so child 0 sits directly above the anchor).
            SliverPadding(
              padding: horizontalPadding,
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => buildChapterSlice(_centerIndex - 1 - i),
                  childCount: _centerIndex,
                ),
              ),
            ),
            // The anchor chapter and everything after it.
            SliverPadding(
              key: _centerKey,
              padding: horizontalPadding,
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => buildChapterSlice(_centerIndex + i),
                  childCount: _chapters.length - _centerIndex,
                ),
              ),
            ),
            // Below the last chapter: next-chapter spinner (continuous) or the
            // prev/next navigation buttons (paged mode / end of book).
            SliverToBoxAdapter(
              child: Padding(
                padding: horizontalPadding,
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.s48),
                    if (widget.continuousReading && !_reachedEnd)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
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
                    const SizedBox(height: AppSpacing.s64),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        children: [
          Text(
            chapter.bookName,
            textAlign: TextAlign.center,
            style: AppTypography.display.copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            '—  CHAPTER ${chapter.chapter}  —',
            style: AppTypography.scriptureRef.copyWith(
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
  final double fontSize;
  final bool showVerseNumber;
  final VoidCallback onTap;

  const _VerseTile({
    super.key,
    required this.verseNumber,
    required this.text,
    required this.selected,
    this.highlightColor,
    required this.fontSize,
    required this.showVerseNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;

    final baseStyle = AppTypography.scripture(
      fontSize,
    ).copyWith(color: colorScheme.onSurface);

    // Strip HTML, decode entities, and keep words-of-Christ segments
    // (red-letter) via sentinel markers.
    final normalized = normalizeResolvedScriptureText(
      text,
      preserveWordsOfChrist: true,
    );
    final spans = buildScriptureSpans(
      normalized,
      baseStyle: baseStyle,
      wordsOfChristColor: wordsOfChristColorFor(brightness),
    );

    // Selection = warm wash + ink accent bar on the left; a selected
    // highlighted verse keeps its highlight color with the accent bar on
    // top (UI_OVERHAUL §3.2).
    final selectionWash = AppColors.selectionWash(brightness);
    final backgroundColor = selected
        ? (highlightColor ?? selectionWash)
        : (highlightColor ?? Colors.transparent);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: selected
              ? Border(left: BorderSide(color: colorScheme.primary, width: 2))
              : null,
          // No radius while the left accent border is present — Flutter
          // forbids borderRadius with a non-uniform Border.
          borderRadius: selected
              ? null
              : BorderRadius.circular(AppRadius.small),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showVerseNumber) ...[
              SizedBox(
                width: 40,
                child: Text(
                  '$verseNumber',
                  style: AppTypography.scriptureRef.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
            ],
            Expanded(child: Text.rich(TextSpan(children: spans))),
          ],
        ),
      ),
    );
  }
}
