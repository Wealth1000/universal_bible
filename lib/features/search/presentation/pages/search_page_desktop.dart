import 'dart:async';
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

/// Search over verse text. A scope selector picks a single translation or
/// "All translations"; results update as the user types (debounced) and are
/// badged with their translation. Tapping a result jumps the reader to that
/// chapter (in that translation).
class SearchPageDesktop extends ConsumerStatefulWidget {
  const SearchPageDesktop({super.key});

  @override
  ConsumerState<SearchPageDesktop> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPageDesktop> {
  static const _resultLimit = 200; // per translation
  static const _minQueryLength = 3;

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<Verse>? _results; // null = nothing searched yet
  bool _searching = false;
  bool _truncated = false;

  // Guards against stale responses when the query or scope changes while a
  // multi-translation search is still running.
  int _searchSeq = 0;

  List<Translation> _translations = const [];
  // Translation id → (book number → display name). Book maps differ per
  // translation, so results are labelled with their own translation's names.
  Map<String, Map<int, String>> _bookNamesById = const {};

  /// Search scope: a translation id, or null for "All translations".
  String? _scopeId;

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadTranslations() async {
    final repo = ref.read(translationRepoProvider);
    final installed = await repo.getInstalled();
    if (!mounted) return;

    final preserveOriginal = ref.read(preserveOriginalBookNamesProvider);
    final namesById = <String, Map<int, String>>{};
    for (final t in installed) {
      final bookMap = jsonDecode(t.bookMapJson) as Map<String, dynamic>;
      final names = <int, String>{};
      bookMap.forEach((name, number) {
        names[number as int] =
            formatBookName(name, preserveOriginal: preserveOriginal);
      });
      namesById[t.id] = names;
    }

    // Default scope: the active translation (reader's cascade), else all.
    final current = ref.read(currentTranslationProvider);
    final scope = installed.any((t) => t.id == current) ? current : null;

    setState(() {
      _translations = installed;
      _bookNamesById = namesById;
      _scopeId = scope;
    });
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(value.trim());
    });
  }

  /// The translations the current scope covers, in installed order.
  List<String> get _scopeIds => _scopeId != null
      ? [_scopeId!]
      : [for (final t in _translations) t.id];

  Future<void> _runSearch(String query) async {
    _searchSeq++;
    final seq = _searchSeq;
    if (!mounted) return;
    if (query.length < _minQueryLength || _scopeIds.isEmpty) {
      setState(() {
        _query = query;
        _results = null;
        _searching = false;
        _truncated = false;
      });
      return;
    }
    setState(() {
      _query = query;
      _searching = true;
    });

    final db = ref.read(databaseProvider);
    final results = <Verse>[];
    var truncated = false;
    for (final id in _scopeIds) {
      final part = await db.searchVerses(id, query, limit: _resultLimit);
      if (part.length >= _resultLimit) truncated = true;
      results.addAll(part);
    }
    if (!mounted || seq != _searchSeq) return; // stale response
    setState(() {
      _results = results;
      _truncated = truncated;
      _searching = false;
    });
  }

  /// Jumps the reader to the result's chapter (in the result's translation,
  /// same provider + persistence pattern the reader's own navigation uses).
  void _openResult(Verse verse) {
    ref.read(currentTranslationProvider.notifier).set(verse.translationId);
    ref.read(currentBookProvider.notifier).set(verse.bookNumber);
    ref.read(currentChapterProvider.notifier).set(verse.chapter);
    ref.read(readingPositionProvider.notifier).save(
          ReadingPosition(
            translationId: verse.translationId,
            book: verse.bookNumber,
            chapter: verse.chapter,
          ),
        );
    context.go('/reader');
  }

  String _scopeLabel() {
    final scope = _scopeId;
    if (scope == null) return 'All';
    return _translations
        .firstWhere((t) => t.id == scope, orElse: () => _translations.first)
        .id;
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
          'Search',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        onChanged: _onQueryChanged,
                        decoration: InputDecoration(
                          hintText: 'Search verses…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _controller.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear',
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    _controller.clear();
                                    _runSearch('');
                                  },
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildScopeSelector(theme, colorScheme),
                  ],
                ),
              ),
              Expanded(child: _buildResults(theme, colorScheme)),
            ],
          ),
        ),
      ),
    );
  }

  /// Translation scope: "All" or a single installed translation.
  Widget _buildScopeSelector(ThemeData theme, ColorScheme colorScheme) {
    return PopupMenuButton<String?>(
      tooltip: 'Search scope',
      initialValue: _scopeId,
      onSelected: (id) {
        setState(() => _scopeId = id);
        _runSearch(_query);
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String?>(
          value: null,
          child: Text('All translations'),
        ),
        for (final t in _translations)
          PopupMenuItem<String>(
            value: t.id,
            child: Text('${t.id} — ${t.name}'),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.translate, size: 18, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              _scopeLabel(),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more, size: 18, color: colorScheme.outline),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(ThemeData theme, ColorScheme colorScheme) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_translations.isEmpty) {
      return Center(
        child: Text(
          'No translations installed.\nImport one from Settings first.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    if (_results == null) {
      return Center(
        child: Text(
          _query.isEmpty
              ? 'Type at least $_minQueryLength characters to search.'
              : 'Keep typing — at least $_minQueryLength characters.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final results = _results!;
    if (results.isEmpty) {
      return Center(
        child: Text(
          'No results for "$_query".',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      itemCount: results.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == results.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: Text(
                _truncated
                    ? 'Showing the first $_resultLimit matches per '
                      'translation — refine your search.'
                    : '${results.length} result${results.length == 1 ? '' : 's'}'
                      '${_scopeId == null ? ' across ${_translations.length} translations' : ''}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        final v = results[index];
        final names = _bookNamesById[v.translationId] ?? const {};
        final reference =
            '${names[v.bookNumber] ?? 'Book ${v.bookNumber}'} '
            '${v.chapter}:${v.verse}';
        return _ResultTile(
          reference: reference,
          translationId: v.translationId,
          // The badge is only informative when more than one translation
          // is in scope.
          showTranslationBadge: _scopeId == null && _translations.length > 1,
          text: normalizeResolvedScriptureText(v.verseText),
          query: _query,
          onTap: () => _openResult(v),
        );
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  final String reference;
  final String translationId;
  final bool showTranslationBadge;
  final String text;
  final String query;
  final VoidCallback onTap;

  const _ResultTile({
    required this.reference,
    required this.translationId,
    required this.showTranslationBadge,
    required this.text,
    required this.query,
    required this.onTap,
  });

  /// Splits [text] into spans with the query matches emphasized.
  List<TextSpan> _highlightMatches(TextStyle base, TextStyle match) {
    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    var start = 0;
    while (true) {
      final i = lower.indexOf(q, start);
      if (i < 0) {
        spans.add(TextSpan(text: text.substring(start), style: base));
        break;
      }
      if (i > start) {
        spans.add(TextSpan(text: text.substring(start, i), style: base));
      }
      spans.add(TextSpan(text: text.substring(i, i + q.length), style: match));
      start = i + q.length;
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final base = theme.textTheme.bodyMedium!.copyWith(
      fontFamily: 'Literata',
      height: 1.5,
    );
    final match = base.copyWith(
      fontWeight: FontWeight.w700,
      color: colorScheme.primary,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    reference,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                if (showTranslationBadge) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      translationId,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(children: _highlightMatches(base, match)),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
