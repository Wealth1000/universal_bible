import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/core/design/app_tokens.dart';

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

/// Opens a bottom sheet showing [reference]. Offline passage resolution isn't
/// wired up in this build (the scripture-resolver module lives in the mobile
/// port, which isn't active), so the sheet shows the reference and points the
/// reader to the Bible tab.
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

class _ScriptureRevealSheet extends StatelessWidget {
  const _ScriptureRevealSheet({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rubric = AppColors.wordsOfChrist(theme.brightness);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
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
          Text(
            'Open the Bible tab to read this passage.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
