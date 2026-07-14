import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_bible/features/bible/domain/reader_provider.dart';
import 'dart:convert';
import '../../../../core/providers/database_provider.dart';
import '../../data/repositories/translation_repository.dart';
import '../../../../database/app_database.dart'; // For Verse type

final _translationRepoProvider = Provider<TranslationRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TranslationRepository(db);
});

// --- BookInfo helper class ---
class BookInfo {
  final int number;
  final String name;
  final Map<int, int> chapterCounts;

  BookInfo({required this.number, required this.name, required this.chapterCounts});
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? colorScheme.primary : const Color(0xFF2E434C);

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

    final versesFuture = translationId != null && book != null && chapter != null
        ? ref.read(databaseProvider).getVersesForChapter(
              translationId,
              book,
              chapter,
            )
        : Future.value(<Verse>[]);

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
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert),
            color: colorScheme.onSurfaceVariant,
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
              // Main content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListView(
                  children: [
                    const SizedBox(height: 16),
                    // Chapter header
                    Center(
                      child: Text(
                        'The First Book of Moses, called $bookName',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Verses
                    ...verses.asMap().entries.map((entry) {
                      final verse = entry.value;
                      final isSelected = _selectedVerseId == verse.id;
                      return _VerseTileMobile(
                        verseNumber: verse.verse,
                        text: verse.verseText,
                        isSelected: isSelected,
                        onTap: () {
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
                        onLongPress: () {
                          setState(() {
                            _selectedVerseId = verse.id;
                            _showContextMenu = true;
                          });
                        },
                      );
                    }),
                    // Decorative image
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.image,
                            size: 48,
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
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
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: 0,
        onTap: (index) {
          if (index == 0) {
            // Already on Bible
          } else if (index == 1) {
            // Navigate to Search
          } else if (index == 2) {
            // Navigate to Bookmarks
          } else if (index == 3) {
            // Navigate to Notes
          } else if (index == 4) {
            context.go('/settings');
          }
        },
      ),
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
              child: Text(
                widget.text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: 'Source Serif 4',
                  fontSize: 16,
                  height: 1.6,
                  color: colorScheme.onSurface,
                ),
              ),
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

// --- Bottom Navigation Bar ---
class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const _BottomNavBar({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final items = [
      {'icon': Icons.menu_book, 'label': 'Bible'},
      {'icon': Icons.search, 'label': 'Search'},
      {'icon': Icons.bookmark, 'label': 'Bookmarks'},
      {'icon': Icons.sticky_note_2, 'label': 'Notes'},
      {'icon': Icons.settings, 'label': 'Settings'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == selectedIndex;
              final icon = item['icon'] as IconData;
              final label = item['label'] as String;

              return InkWell(
                onTap: () => onTap(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.secondaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: isSelected
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? colorScheme.onSecondaryContainer
                              : colorScheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}