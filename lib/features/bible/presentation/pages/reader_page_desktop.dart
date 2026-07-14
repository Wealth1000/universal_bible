import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_bible/database/app_database.dart';
import 'package:universal_bible/features/bible/domain/reader_provider.dart';
import 'dart:convert';
import '../../../../core/providers/database_provider.dart';
import '../../data/repositories/translation_repository.dart';



// --- Repository provider ---
final _translationRepoProvider = Provider<TranslationRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TranslationRepository(db);
});

// --- Helper to load book list and chapter counts ---
class BookInfo {
  final int number;
  final String name;
  final Map<int, int> chapterCounts;

  BookInfo({required this.number, required this.name, required this.chapterCounts});
}

// --- Reader Page ---
class ReaderPageDesktop extends ConsumerStatefulWidget {
  const ReaderPageDesktop({super.key});

  @override
  ConsumerState<ReaderPageDesktop> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPageDesktop> {
  List<BookInfo>? _books;
  Map<int, int>? _chapterCounts;
  bool _isLoading = true;
  bool _selectionFabVisible = false;
  String _selectedText = '';

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final repo = ref.read(_translationRepoProvider);
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

    final books = <BookInfo>[];
    for (final entry in sortedEntries) {
      final name = entry.key;
      final number = entry.value as int;
      final counts = bookChapters[number] ?? {};
      books.add(BookInfo(
        number: number,
        name: _capitalize(name),
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

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final primaryColor = isDark
        ? colorScheme.primary
        : const Color(0xFF2E434C);
    final onSurfaceVariant = colorScheme.onSurfaceVariant;
    final surfaceColor = theme.scaffoldBackgroundColor;

    final translationId = ref.watch(currentTranslationProvider);
    final book = ref.watch(currentBookProvider);
    final chapter = ref.watch(currentChapterProvider);

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
                color: onSurfaceVariant,
              ),
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
    final currentChapter = chapter ?? (chapterKeys.isNotEmpty ? chapterKeys.first : 1);

    final versesFuture = translationId != null && book != null && chapter != null
        ? ref.read(databaseProvider).getVersesForChapter(
              translationId,
              book,
              chapter,
            )
        : Future.value(<Verse>[]);

    return Scaffold(
      backgroundColor: surfaceColor,
      body: Row(
        children: [
          // Desktop Navigation Rail
          _NavigationRail(
            selectedIndex: 0,
            onItemSelected: (index) {
              if (index == 2) {
                context.go('/translations');
              }
              // Other indexes can be implemented later
            },
          ),
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Bar
                _TopBar(
                  bookName: bookName,
                  chapter: currentChapter,
                  books: _books!,
                  chapterKeys: chapterKeys,
                  translationId: translationId,
                  onBookChanged: (newBook) {
                    ref.read(currentBookProvider.notifier).set(newBook.number);
                    setState(() {
                      _chapterCounts = newBook.chapterCounts;
                      final firstChapter = newBook.chapterCounts.keys.isNotEmpty
                          ? newBook.chapterCounts.keys.first
                          : 1;
                      ref.read(currentChapterProvider.notifier).set(firstChapter);
                    });
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
                        verses: verses,
                        bookName: bookName,
                        chapter: currentChapter,
                        onTextSelected: (text) {
                          setState(() {
                            if (text.isNotEmpty) {
                              _selectedText = text;
                              _selectionFabVisible = true;
                            } else {
                              _selectionFabVisible = false;
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
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
                  Container(
                    width: 1,
                    height: 20,
                    color: Colors.white30,
                  ),
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

// --- Navigation Rail Widget ---
class _NavigationRail extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const _NavigationRail({
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;

    final items = [
      {'icon': Icons.menu_book, 'label': 'Bible'},
      {'icon': Icons.search, 'label': 'Search'},
      {'icon': Icons.translate, 'label': 'Translations'},
      {'icon': Icons.bookmark, 'label': 'Bookmarks'},
      {'icon': Icons.sticky_note_2, 'label': 'Notes'},
      {'icon': Icons.download, 'label': 'Downloads'},
      {'icon': Icons.settings, 'label': 'Settings'},
    ];

    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Image.asset(
              'assets/images/app_logo.png',
              width: 40,
              height: 40,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final isSelected = index == selectedIndex;
                final icon = items[index]['icon'] as IconData;
                final label = items[index]['label'] as String;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.secondaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: InkWell(
                    onTap: () => onItemSelected(index),
                    borderRadius: BorderRadius.circular(32),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            color: isSelected
                                ? colorScheme.onSecondaryContainer
                                : onSurfaceVariant,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isSelected
                                  ? colorScheme.onSecondaryContainer
                                  : onSurfaceVariant,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'v1.0',
              style: theme.textTheme.labelSmall?.copyWith(
                color: onSurfaceVariant.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
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
  final Function(BookInfo) onBookChanged;
  final Function(int) onChapterChanged;
  final VoidCallback onTranslationTap;

  const _TopBar({
    required this.bookName,
    required this.chapter,
    required this.books,
    required this.chapterKeys,
    this.translationId,
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
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_vert),
                color: colorScheme.onSurfaceVariant,
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
  final List<Verse> verses;
  final String bookName;
  final int chapter;
  final Function(String) onTextSelected;

  const _ReaderContent({
    required this.verses,
    required this.bookName,
    required this.chapter,
    required this.onTextSelected,
  });

  @override
  State<_ReaderContent> createState() => _ReaderContentState();
}

class _ReaderContentState extends State<_ReaderContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;

    return Scrollbar(
      controller: _scrollController,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  widget.bookName,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Chapter ${widget.chapter}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          ...widget.verses.map((verse) {
            return _VerseTile(
              verseNumber: verse.verse,
              text: verse.verseText,
              onSelected: (text) {
                widget.onTextSelected(text);
              },
            );
          }),
          const SizedBox(height: 48),
          Center(
            child: TextButton(
              onPressed: () {
                // TODO: navigate to next chapter
              },
              style: TextButton.styleFrom(
                side: BorderSide(
                  color: colorScheme.outlineVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Continue to ${widget.bookName} ${widget.chapter + 1}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 64),
        ],
      ),
    );
  }
}

// --- Individual Verse Tile ---
class _VerseTile extends StatefulWidget {
  final int verseNumber;
  final String text;
  final Function(String) onSelected;

  const _VerseTile({
    required this.verseNumber,
    required this.text,
    required this.onSelected,
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

    return GestureDetector(
      onTap: () {
        setState(() {
          _isSelected = !_isSelected;
        });
      },
      onLongPress: () {
        widget.onSelected(widget.text);
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
              child: SelectableText(
                widget.text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: 'Source Serif 4',
                  fontSize: 16,
                  height: 1.6,
                  color: colorScheme.onSurface,
                ),
                onSelectionChanged: (selection, cause) {
                  if (selection.baseOffset != selection.extentOffset) {
                    final selectedText = widget.text.substring(
                      selection.baseOffset,
                      selection.extentOffset,
                    );
                    widget.onSelected(selectedText);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}