import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_bible/core/providers/database_provider.dart';
import 'package:universal_bible/core/providers/translation_repo_provider.dart';
import 'package:universal_bible/core/utils/scripture_format.dart';
import 'package:universal_bible/database/app_database.dart'
    hide ReadingPosition;
import 'package:universal_bible/features/bible/domain/reader_provider.dart';

/// One translation's rendering of the compared selection.
class _TranslationBlock {
  final Translation translation;
  // Parallel to the refs list; null = verse not in this translation.
  final List<String?> verseTexts;

  const _TranslationBlock(this.translation, this.verseTexts);
}

/// §6 comparison column: the selected verse(s) in every installed
/// translation, stacked vertically, alphabetical by abbreviation (Q3).
/// Read-only beyond scrolling. Used both in the reader split view and the
/// routed full-screen compare page.
class CompareColumn extends ConsumerStatefulWidget {
  /// Selection in reading order.
  final List<VerseRef> refs;

  /// Book display name for a book number (translation-independent label).
  final String Function(int book) bookNameFor;

  /// Split-view close (×). Hidden when null (full-screen page).
  final VoidCallback? onClose;

  /// "Open full screen" action. Hidden when null (already full screen).
  final VoidCallback? onExpand;

  const CompareColumn({
    super.key,
    required this.refs,
    required this.bookNameFor,
    this.onClose,
    this.onExpand,
  });

  @override
  ConsumerState<CompareColumn> createState() => _CompareColumnState();
}

class _CompareColumnState extends ConsumerState<CompareColumn> {
  Future<List<_TranslationBlock>>? _blocksFuture;
  String? _blocksKey;

  Future<List<_TranslationBlock>> _loadBlocks() async {
    final translations = await ref.read(translationRepoProvider).getInstalled();
    translations.sort(
      (a, b) => a.id.toLowerCase().compareTo(b.id.toLowerCase()),
    );
    final db = ref.read(databaseProvider);
    final blocks = <_TranslationBlock>[];
    for (final t in translations) {
      final texts = <String?>[];
      for (final v in widget.refs) {
        final row = await db.getVerse(t.id, v.book, v.chapter, v.verse);
        texts.add(row?.verseText);
      }
      blocks.add(_TranslationBlock(t, texts));
    }
    return blocks;
  }

  Future<List<_TranslationBlock>> _ensureBlocks() {
    // Re-fetch only when the selection actually changes (live updates).
    final key = widget.refs.map((r) => r.toString()).join(',');
    if (_blocksKey != key || _blocksFuture == null) {
      _blocksKey = key;
      _blocksFuture = _loadBlocks();
    }
    return _blocksFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: title + expand + close.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Icon(Icons.view_column_outlined,
                  size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Compare',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (widget.onExpand != null)
                IconButton(
                  tooltip: 'Open full screen',
                  icon: const Icon(Icons.open_in_full, size: 20),
                  onPressed: widget.onExpand,
                ),
              if (widget.onClose != null)
                IconButton(
                  tooltip: 'Close compare',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: widget.onClose,
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<_TranslationBlock>>(
            future: _ensureBlocks(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final blocks = snapshot.data!;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  for (var i = 0; i < blocks.length; i++) ...[
                    if (i > 0) const Divider(height: 32),
                    _blockWidget(theme, blocks[i]),
                  ],
                  if (blocks.length <= 1) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Install more translations'),
                        onPressed: () => context.go('/translations'),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _blockWidget(ThemeData theme, _TranslationBlock block) {
    final colorScheme = theme.colorScheme;
    final baseStyle = theme.textTheme.bodyLarge!.copyWith(
      fontFamily: 'Literata',
      fontSize: 15,
      height: 1.6,
      color: colorScheme.onSurface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "ABBR → Full Name" header per spec.
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: block.translation.id,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              TextSpan(
                text: ' → ${block.translation.name}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < widget.refs.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Text(
            '${widget.bookNameFor(widget.refs[i].book)} '
            '${widget.refs[i].chapter}:${widget.refs[i].verse}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          if (block.verseTexts[i] == null)
            Text(
              'Not available in this translation.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            Text.rich(
              TextSpan(
                children: buildScriptureSpans(
                  normalizeResolvedScriptureText(
                    block.verseTexts[i]!,
                    preserveWordsOfChrist: true,
                  ),
                  baseStyle: baseStyle,
                  wordsOfChristColor:
                      wordsOfChristColorFor(theme.brightness),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
