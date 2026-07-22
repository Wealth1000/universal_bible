import 'package:flutter/material.dart';

/// Adaptive grid of chapter numbers for the reader top bar. Mirrors the
/// translation grid pattern (§2): a Wrap of content-sized number cells, the
/// active chapter highlighted. Tapping a cell selects it and closes the
/// surface via [onClose]. Numbers only — the "Chapter N" wording lives on
/// the anchor button, not in the grid.
class ChapterGrid extends StatelessWidget {
  final List<int> chapterKeys;
  final int currentChapter;
  final ValueChanged<int> onSelected;
  final VoidCallback onClose;

  const ChapterGrid({
    super.key,
    required this.chapterKeys,
    required this.currentChapter,
    required this.onSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final ch in chapterKeys)
            _ChapterCell(
              chapter: ch,
              isActive: ch == currentChapter,
              onTap: () {
                onSelected(ch);
                onClose();
              },
            ),
        ],
      ),
    );
  }
}

class _ChapterCell extends StatelessWidget {
  final int chapter;
  final bool isActive;
  final VoidCallback onTap;

  const _ChapterCell({
    required this.chapter,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      selected: isActive,
      label: 'Chapter $chapter${isActive ? ', current chapter' : ''}',
      child: Material(
        color: isActive ? colorScheme.primaryContainer : colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isActive ? colorScheme.primary : colorScheme.outlineVariant,
            width: isActive ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              '$chapter',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isActive
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop: shows [ChapterGrid] as a dropdown box anchored below the chapter
/// button (below-left, growing leftwards), mirroring the translation grid
/// dropdown. Dismissed on tap-outside.
void showChapterGridDropdown(
  BuildContext context, {
  required List<int> chapterKeys,
  required int currentChapter,
  required ValueChanged<int> onSelected,
  GlobalKey? anchorKey,
}) {
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

  // Anchor rect in overlay coordinates; falls back to a top-left region.
  Rect anchorRect;
  final anchorBox = anchorKey?.currentContext?.findRenderObject() as RenderBox?;
  if (anchorBox != null && anchorBox.attached) {
    anchorRect = Rect.fromPoints(
      anchorBox.localToGlobal(Offset.zero, ancestor: overlay),
      anchorBox.localToGlobal(
        anchorBox.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    );
  } else {
    anchorRect = const Rect.fromLTWH(120, 56, 64, 32);
  }

  showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return Stack(
        children: [
          Positioned(
            top: anchorRect.bottom + 4,
            left: anchorRect.left.clamp(8.0, overlay.size.width - 8.0),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(16),
              color: theme.colorScheme.surface,
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320, maxHeight: 420),
                child: SingleChildScrollView(
                  child: ChapterGrid(
                    chapterKeys: chapterKeys,
                    currentChapter: currentChapter,
                    onSelected: onSelected,
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
