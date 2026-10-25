import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_bible/core/providers/database_provider.dart';
import 'package:universal_bible/core/providers/translation_repo_provider.dart';
import 'package:universal_bible/database/app_database.dart';
import 'package:universal_bible/features/bible/domain/reader_provider.dart';

/// Switches the active translation WITHOUT touching the current
/// book/chapter — the reader stays where the user was (1 Kings 5 [NKJV]
/// → NLT stays at 1 Kings 5). Only the translation component of the
/// persisted reading position is updated.
void _activateTranslation(WidgetRef ref, String id) {
  ref.read(currentTranslationProvider.notifier).set(id);
  ref.read(readingPositionProvider.notifier).saveTranslationOnly(id);
}

/// Adaptive grid of installed translations (§2). A Wrap of content-sized
/// cells — the box grows/shrinks with its content instead of using fixed
/// columns. The active translation is highlighted; tapping a cell
/// activates it and closes the surface via [onClose].
class TranslationGrid extends ConsumerWidget {
  final VoidCallback onClose;

  const TranslationGrid({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(translationRepoProvider);
    final activeId = ref.watch(currentTranslationProvider);

    return FutureBuilder<List<Translation>>(
      future: repo.getInstalled(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final translations = snapshot.data!;
        final theme = Theme.of(context);

        return Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 470,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 2.0,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: translations.length,
                  itemBuilder: (context, index) {
                    final t = translations[index];
                    return _TranslationCell(
                      translation: t,
                      isActive: t.id == activeId,
                      onTap: () {
                        _activateTranslation(ref, t.id);
                        onClose();
                      },
                    );
                  },
                ),
              ),
              if (translations.length <= 1) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Install more translations'),
                  onPressed: () {
                    onClose();
                    context.go('/translations');
                  },
                ),
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  '${translations.length} installed',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TranslationCell extends StatelessWidget {
  final Translation translation;
  final bool isActive;
  final VoidCallback onTap;

  const _TranslationCell({
    required this.translation,
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
      label:
          '${translation.name} (${translation.id})'
          '${isActive ? ', active translation' : ''}',
      child: Material(
        color: isActive ? colorScheme.primaryContainer : colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isActive ? colorScheme.primary : colorScheme.outlineVariant,
            width: isActive ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translation.id,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  translation.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isActive
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
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

/// Desktop: shows [TranslationGrid] as a dropdown box anchored below the
/// pill (below-left: the grid's right edge aligns near the pill's right
/// edge, growing leftwards). Dismissed on tap-outside.
void showTranslationGridDropdown(BuildContext context, {GlobalKey? anchorKey}) {
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

  // Anchor rect in overlay coordinates; falls back to top-right region.
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
    anchorRect = Rect.fromLTWH(overlay.size.width - 120, 56, 64, 32);
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
            right: (overlay.size.width - anchorRect.right - 20).clamp(
              8.0,
              overlay.size.width - 8.0,
            ),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(16),
              color: theme.colorScheme.surface,
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Consumer(
                  builder: (context, ref, _) => TranslationGrid(
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

/// Mobile: shows [TranslationGrid] in a modal bottom sheet, matching the
/// book/chapter picker pattern.
void showTranslationGridSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Select Translation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Divider(),
            SingleChildScrollView(
              child: TranslationGrid(
                onClose: () => Navigator.of(sheetContext).pop(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
