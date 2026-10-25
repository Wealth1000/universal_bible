import 'package:flutter/material.dart';

/// Adaptive grid of chapter numbers for the reader top bar.
/// Keeps exactly 8 columns. Cell size is controlled by [maxGridWidth] –
/// set a smaller value to get smaller squares.
class ChapterGrid extends StatelessWidget {
  final List<int> chapterKeys;
  final int currentChapter;
  final ValueChanged<int> onSelected;
  final VoidCallback onClose;
  final double? maxGridWidth; // ← narrower width → smaller squares

  const ChapterGrid({
    super.key,
    required this.chapterKeys,
    required this.currentChapter,
    required this.onSelected,
    required this.onClose,
    this.maxGridWidth = 332,
  });

  @override
  Widget build(BuildContext context) {
    const crossAxisCount = 8;
    const mainAxisSpacing = 4.0;
    const crossAxisSpacing = 4.0;
    const padding = EdgeInsets.all(8.0);

    final totalItems = chapterKeys.length;
    final rowCount = (totalItems / crossAxisCount).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the specified max width, otherwise fill the parent.
        final usedWidth = maxGridWidth ?? constraints.maxWidth;
        final availableWidth = usedWidth - padding.horizontal;
        final tileWidth = (availableWidth -
                (crossAxisCount - 1) * crossAxisSpacing) /
            crossAxisCount;
        // Square cells → height = width
        final tileHeight = tileWidth;
        final gridHeight = padding.vertical +
            rowCount * tileHeight +
            (rowCount - 1) * mainAxisSpacing;

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: usedWidth),
          child: SizedBox(
            height: gridHeight,
            child: GridView.count(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1.0,
              padding: padding,
              mainAxisSpacing: mainAxisSpacing,
              crossAxisSpacing: crossAxisSpacing,
              children: chapterKeys.map((ch) {
                final isActive = ch == currentChapter;
                return _ChapterCell(
                  chapter: ch,
                  isActive: isActive,
                  onTap: () {
                    onSelected(ch);
                    onClose();
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
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
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isActive ? colorScheme.primary : colorScheme.outlineVariant,
            width: isActive ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Text(
              '$chapter',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isActive
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop: shows [ChapterGrid] as a dropdown box anchored below the chapter
/// button. The grid is forced to a narrower width (`maxGridWidth = 400`) to
/// make the squares visibly smaller while keeping 8 columns.
void showChapterGridDropdown(
  BuildContext context, {
  required List<int> chapterKeys,
  required int currentChapter,
  required ValueChanged<int> onSelected,
  GlobalKey? anchorKey,
}) {
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

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
                // Outer box still has a maxWidth to keep the popup tidy
                constraints: const BoxConstraints(
                  maxWidth: 540,
                  maxHeight: 400,
                ),
                // Pass the narrower width directly to the grid
                child: ChapterGrid(
                  chapterKeys: chapterKeys,
                  currentChapter: currentChapter,
                  onSelected: onSelected,
                  onClose: () => Navigator.of(dialogContext).pop(),
                  maxGridWidth: 400,   // ← this makes the squares smaller
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}