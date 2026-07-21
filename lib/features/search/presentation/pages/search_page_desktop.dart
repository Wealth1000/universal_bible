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

/// Search over the active translation's verse text. Results update as the
/// user types (debounced); tapping a result jumps the reader to that
/// chapter.
class SearchPageDesktop extends ConsumerStatefulWidget {
  const SearchPageDesktop({super.key});

  @override
  ConsumerState<SearchPageDesktop> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPageDesktop> {
  static const _resultLimit = 200;
  static const _minQueryLength = 3;

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<Verse>? _results; // null = nothing searched yet
  bool _searching = false;
  bool _truncated = false;

  // Book number → display name for the active translation (same derivation
  // as ComparePageDesktop).
  Map<int, String> _bookNames = const {};
  String? _translationId;

  @override
  void initState() {
    super.initState();
    _loadBookNames();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadBookNames() async {
    // Search the active translation; fall back to the first installed one
    // (e.g. when Search is opened before the reader ever ran).
    var translationId = ref.read(currentTranslationProvider);
    final repo = ref.read(translationRepoProvider);
    if (translationId == null) {
      final installed = await repo.getInstalled();
      if (installed.isEmpty) return;
      translationId = installed.first.id;
    }
    final trans = await repo.get(translationId);
    if (trans == null) return;
    final bookMap = jsonDecode(trans.bookMapJson) as Map<String, dynamic>;
    final preserveOriginal = ref.read(preserveOriginalBookNamesProvider);
    final names = <int, String>{};
    bookMap.forEach((name, number) {
      names[number as int] =
          formatBookName(name, preserveOriginal: preserveOriginal);
    });
    if (mounted) {
      setState(() {
        _translationId = translationId;
        _bookNames = names;
      });
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(value.trim());
    });
  }

  Future<void> _runSearch(String query) async {
    if (!mounted) return;
    if (query.length < _minQueryLength || _translationId == null) {
      setState(() {
        _query = query;
        _results = null;
        _searching = false;
      });
      return;
    }
    setState(() {
      _query = query;
      _searching = true;
    });
    final results = await ref
        .read(databaseProvider)
        .searchVerses(_translationId!, query, limit: _resultLimit);
    if (!mounted || _query != query) return; // stale response
    setState(() {
      _results = results;
      _truncated = results.length >= _resultLimit;
      _searching = false;
    });
  }

  /// Jumps the reader to the result's chapter (same provider + persistence
  /// pattern the reader's own navigation uses).
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
              Expanded(child: _buildResults(theme, colorScheme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(ThemeData theme, ColorScheme colorScheme) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
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
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == results.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: Text(
                _truncated
                    ? 'Showing the first $_resultLimit matches — refine your search.'
                    : '${results.length} result${results.length == 1 ? '' : 's'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        final v = results[index];
        final reference =
            '${_bookNames[v.bookNumber] ?? 'Book ${v.bookNumber}'} '
            '${v.chapter}:${v.verse}';
        return _ResultTile(
          reference: reference,
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
  final String text;
  final String query;
  final VoidCallback onTap;

  const _ResultTile({
    required this.reference,
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
            Text(
              reference,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
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
