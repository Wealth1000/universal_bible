import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_bible/core/providers/database_provider.dart';
import 'package:universal_bible/core/providers/translation_repo_provider.dart';
import 'package:universal_bible/core/utils/book_name_utils.dart';
import 'package:universal_bible/core/utils/scripture_format.dart';
import 'package:universal_bible/database/app_database.dart'
    hide ReadingPosition;
import 'package:universal_bible/features/bible/domain/reader_provider.dart';
import 'package:universal_bible/features/settings/domain/book_name_settings_provider.dart';

/// Bookmarks for the active translation, newest first. Tapping a bookmark
/// jumps the reader to its chapter; deletion is immediate (single tap,
/// per UI_UX §13 — undo via re-bookmarking in the reader).
class BookmarksPageDesktop extends ConsumerStatefulWidget {
  const BookmarksPageDesktop({super.key});

  @override
  ConsumerState<BookmarksPageDesktop> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends ConsumerState<BookmarksPageDesktop> {
  String? _translationId;
  Map<int, String> _bookNames = const {};
  List<Bookmark>? _bookmarks;
  // Bookmark id → verse text preview.
  final Map<String, String> _previews = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var translationId = ref.read(currentTranslationProvider);
    final repo = ref.read(translationRepoProvider);
    if (translationId == null) {
      final installed = await repo.getInstalled();
      if (installed.isEmpty) {
        if (mounted) setState(() => _bookmarks = const []);
        return;
      }
      translationId = installed.first.id;
    }
    final trans = await repo.get(translationId);
    final names = <int, String>{};
    if (trans != null) {
      final bookMap = jsonDecode(trans.bookMapJson) as Map<String, dynamic>;
      final preserveOriginal = ref.read(preserveOriginalBookNamesProvider);
      bookMap.forEach((name, number) {
        names[number as int] =
            formatBookName(name, preserveOriginal: preserveOriginal);
      });
    }

    final db = ref.read(databaseProvider);
    final rows = await db.getBookmarksForTranslation(translationId);
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Verse text previews.
    final previews = <String, String>{};
    for (final b in rows) {
      final v =
          await db.getVerse(b.translationId, b.bookNumber, b.chapter, b.verse);
      if (v != null) {
        previews[b.id] = normalizeResolvedScriptureText(v.verseText);
      }
    }

    if (!mounted) return;
    setState(() {
      _translationId = translationId;
      _bookNames = names;
      _bookmarks = rows;
      _previews
        ..clear()
        ..addAll(previews);
    });
  }

  void _openBookmark(Bookmark b) {
    ref.read(currentTranslationProvider.notifier).set(b.translationId);
    ref.read(currentBookProvider.notifier).set(b.bookNumber);
    ref.read(currentChapterProvider.notifier).set(b.chapter);
    ref.read(readingPositionProvider.notifier).save(
          ReadingPosition(
            translationId: b.translationId,
            book: b.bookNumber,
            chapter: b.chapter,
          ),
        );
    context.go('/reader');
  }

  Future<void> _deleteBookmark(Bookmark b) async {
    await ref.read(databaseProvider).deleteBookmark(b.id);
    if (!mounted) return;
    setState(() {
      _bookmarks?.remove(b);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(
          'Bookmarks',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          ),
        ),
      ),
      body: _bookmarks == null
          ? const Center(child: CircularProgressIndicator())
          : _bookmarks!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_outline,
                          size: 48, color: colorScheme.outline),
                      const SizedBox(height: 12),
                      Text(
                        'No bookmarks yet.\nSelect verses in the reader and tap Save.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _bookmarks!.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final b = _bookmarks![index];
                        final reference =
                            '${_bookNames[b.bookNumber] ?? 'Book ${b.bookNumber}'} '
                            '${b.chapter}:${b.verse}';
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 4),
                          leading: Icon(Icons.bookmark,
                              color: colorScheme.primary),
                          title: Text(
                            '$reference — ${_translationId ?? ''}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: _previews[b.id] == null
                              ? null
                              : Text(
                                  _previews[b.id]!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'Literata',
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                          trailing: IconButton(
                            tooltip: 'Remove bookmark',
                            icon: Icon(Icons.delete_outline,
                                color: colorScheme.onSurfaceVariant),
                            onPressed: () => _deleteBookmark(b),
                          ),
                          onTap: () => _openBookmark(b),
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}
