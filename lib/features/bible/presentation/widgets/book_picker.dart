import 'package:flutter/material.dart';
import 'package:universal_bible/features/bible/domain/book_info.dart';

/// Scrollable list of books for the reader top bar.
/// Shows all books with the current book highlighted.
/// Supports keyboard navigation and follows the visual language of ChapterGrid.
class BookPicker extends StatefulWidget {
  final List<BookInfo> books;
  final String currentBookName;
  final ValueChanged<BookInfo> onSelected;
  final VoidCallback onClose;

  const BookPicker({
    super.key,
    required this.books,
    required this.currentBookName,
    required this.onSelected,
    required this.onClose,
  });

  @override
  State<BookPicker> createState() => _BookPickerState();
}

class _BookPickerState extends State<BookPicker> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentBook();
    });
  }

  void _scrollToCurrentBook() {
    final currentIndex = widget.books.indexWhere(
      (b) => b.name == widget.currentBookName,
    );
    if (!_controller.hasClients || currentIndex < 0) return;

    // Calculate approximate positions
    const itemHeight = 40.0;
    const headerHeight = 37.0;
    final viewportHeight = _controller.position.viewportDimension;

    // Position of the current item (including header)
    final itemTop = currentIndex * itemHeight + headerHeight;
    // Target scroll position to center the item
    final targetOffset = itemTop - (viewportHeight / 2) + (itemHeight / 2);
    // Clamp to valid range
    final maxScroll = _controller.position.maxScrollExtent;

    _controller.jumpTo(targetOffset.clamp(0.0, maxScroll));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const padding = EdgeInsets.all(8.0);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220, maxHeight: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Text(
              'Select Book',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: ListView.builder(
                controller: _controller,
                shrinkWrap: true,
                padding: padding,
                itemCount: widget.books.length,
                itemBuilder: (context, index) {
                  final book = widget.books[index];
                  final isActive = book.name == widget.currentBookName;
                  return _BookCell(
                    book: book,
                    isActive: isActive,
                    onTap: () {
                      widget.onSelected(book);
                      widget.onClose();
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookCell extends StatelessWidget {
  final BookInfo book;
  final bool isActive;
  final VoidCallback onTap;

  const _BookCell({
    required this.book,
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
      label: '${book.name}${isActive ? ', current book' : ''}',
      child: Material(
        color: isActive ? colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    book.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop: shows [BookPicker] as a dropdown box anchored below the book
/// button. Matches the pattern of showChapterGridDropdown.
void showBookPickerDropdown(
  BuildContext context, {
  required List<BookInfo> books,
  required String currentBookName,
  required ValueChanged<BookInfo> onSelected,
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
            left: (anchorRect.left + 30).clamp(
              8.0,
              overlay.size.width - 220 - 8.0,
            ),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(16),
              color: theme.colorScheme.surface,
              clipBehavior: Clip.antiAlias,
              child: BookPicker(
                books: books,
                currentBookName: currentBookName,
                onSelected: onSelected,
                onClose: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ),
        ],
      );
    },
  );
}
