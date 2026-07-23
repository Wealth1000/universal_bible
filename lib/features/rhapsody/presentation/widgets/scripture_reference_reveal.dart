import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_bible/core/design/app_tokens.dart';
import 'package:universal_bible/core/utils/scripture_format.dart';
import 'package:universal_bible/features/bible/domain/reader_provider.dart';
import 'package:universal_bible/features/rhapsody/application/scripture_resolver.dart';

/// Rubricated pill for a single scripture reference in a reading-plan list.
/// Tapping reveals the passage (see [showScriptureReveal]). The garnet rubric
/// is the app's reserved scripture colour, so these read as "doorways to the
/// Word" — consistent with the inline references in the devotional body.
class ScriptureRefChip extends ConsumerWidget {
  const ScriptureRefChip({super.key, required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rubric = AppColors.wordsOfChrist(Theme.of(context).brightness);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showScriptureReveal(context, reference),
        child: Ink(
          decoration: BoxDecoration(
            color: rubric.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: rubric.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 14,
                color: rubric.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 7),
              Text(
                reference,
                style: TextStyle(
                  fontFamily: AppFonts.scripture,
                  fontSize: 14,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: rubric,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a bottom sheet showing [reference] — its resolved passage text from
/// the local database when available (see [scripturePassageProvider]), with a
/// graceful fallback message when the reference can't be resolved.
Future<void> showScriptureReveal(BuildContext context, String reference) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => _ScriptureRevealSheet(reference: reference),
  );
}

class _ScriptureRevealSheet extends ConsumerWidget {
  const _ScriptureRevealSheet({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rubric = AppColors.wordsOfChrist(theme.brightness);
    final passageAsync = ref.watch(scripturePassageProvider(reference));

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_rounded, size: 18, color: rubric),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reference,
                    style: TextStyle(
                      fontFamily: AppFonts.scripture,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: rubric,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: passageAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => _FallbackMessage(
                  message: "Couldn't load this passage. "
                      'Open the Bible tab to read it.',
                ),
                data: (passage) => _PassageBody(passage: passage),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the resolved verses (or a status-specific fallback message) plus an
/// "Open in reader" action when the passage was found.
class _PassageBody extends ConsumerWidget {
  const _PassageBody({required this.passage});

  final ResolvedPassage passage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (passage.status != PassageStatus.ok) {
      return _FallbackMessage(message: _messageFor(passage.status));
    }

    final rubric = AppColors.wordsOfChrist(theme.brightness);
    final baseStyle = TextStyle(
      fontFamily: AppFonts.scripture,
      fontSize: 16.5,
      height: 1.6,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.92),
    );
    final numberStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.secondary,
      fontWeight: FontWeight.w700,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final v in passage.verses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${v.verse}  ', style: numberStyle),
                          ...buildScriptureSpans(
                            normalizeResolvedScriptureText(
                              v.text,
                              preserveWordsOfChrist: true,
                            ),
                            baseStyle: baseStyle,
                            wordsOfChristColor: rubric,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (passage.translationName != null)
              Expanded(
                child: Text(
                  passage.translationName!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    letterSpacing: 0.5,
                  ),
                ),
              )
            else
              const Spacer(),
            TextButton.icon(
              onPressed: () => _openInReader(context, ref, passage),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Open in reader'),
            ),
          ],
        ),
      ],
    );
  }

  void _openInReader(BuildContext context, WidgetRef ref, ResolvedPassage p) {
    if (p.translationId != null) {
      ref.read(currentTranslationProvider.notifier).set(p.translationId!);
    }
    if (p.bookNumber != null) {
      ref.read(currentBookProvider.notifier).set(p.bookNumber!);
    }
    if (p.chapter != null) {
      ref.read(currentChapterProvider.notifier).set(p.chapter!);
    }
    Navigator.of(context).pop();
    context.go('/reader');
  }

  String _messageFor(PassageStatus status) {
    switch (status) {
      case PassageStatus.noTranslation:
        return 'Install a translation to read this passage.';
      case PassageStatus.noVerses:
        return "This passage isn't in the current translation. "
            'Try another translation in the Bible tab.';
      case PassageStatus.bookNotFound:
      case PassageStatus.unparseable:
      case PassageStatus.ok:
        return 'Open the Bible tab to read this passage.';
    }
  }
}

class _FallbackMessage extends StatelessWidget {
  const _FallbackMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      message,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        height: 1.5,
      ),
    );
  }
}
