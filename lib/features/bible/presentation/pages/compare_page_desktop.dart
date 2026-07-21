import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_bible/core/providers/translation_repo_provider.dart';
import 'package:universal_bible/core/utils/book_name_utils.dart';
import 'package:universal_bible/features/bible/domain/reader_provider.dart';
import 'package:universal_bible/features/bible/presentation/widgets/compare_column.dart';
import 'package:universal_bible/features/settings/domain/book_name_settings_provider.dart';

/// §6 owner addition: routed full-screen comparison of the selected
/// verse(s) across all installed translations. Reached from the split-view
/// compare pane's "open full screen" action via `context.push`, so the
/// standard back navigation returns to the reader with the split view and
/// selection intact (providers are untouched).
class ComparePageDesktop extends ConsumerStatefulWidget {
  const ComparePageDesktop({super.key});

  @override
  ConsumerState<ComparePageDesktop> createState() => _ComparePageState();
}

class _ComparePageState extends ConsumerState<ComparePageDesktop> {
  // Book number → display name, derived from the active translation's
  // book map (this page can't receive the reader's loaded book list
  // through a route).
  Map<int, String>? _bookNames;

  @override
  void initState() {
    super.initState();
    _loadBookNames();
  }

  Future<void> _loadBookNames() async {
    final translationId = ref.read(currentTranslationProvider);
    if (translationId == null) {
      setState(() => _bookNames = const {});
      return;
    }
    final trans = await ref.read(translationRepoProvider).get(translationId);
    if (trans == null) {
      if (mounted) setState(() => _bookNames = const {});
      return;
    }
    final bookMap = jsonDecode(trans.bookMapJson) as Map<String, dynamic>;
    final preserveOriginal = ref.read(preserveOriginalBookNamesProvider);
    final names = <int, String>{};
    bookMap.forEach((name, number) {
      names[number as int] =
          formatBookName(name, preserveOriginal: preserveOriginal);
    });
    if (mounted) setState(() => _bookNames = names);
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedVersesProvider).toList()
      ..sort((a, b) {
        if (a.book != b.book) return a.book - b.book;
        if (a.chapter != b.chapter) return a.chapter - b.chapter;
        return a.verse - b.verse;
      });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to reader',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Compare — ${selected.length} verse${selected.length == 1 ? '' : 's'}',
        ),
      ),
      body: _bookNames == null
          ? const Center(child: CircularProgressIndicator())
          : selected.isEmpty
              ? const Center(child: Text('No verses selected.'))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: CompareColumn(
                      refs: selected,
                      bookNameFor: (book) =>
                          _bookNames![book] ?? 'Book $book',
                    ),
                  ),
                ),
    );
  }
}
