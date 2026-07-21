import 'package:flutter/material.dart';

/// §5 verse selection action panel + highlight color helpers.
///
/// Preset highlight colors (Q1: R, G, B) are semi-transparent so scripture
/// text stays legible over them in both light and dark themes. Colors are
/// persisted in the Drift `highlights.color` column as `#AARRGGBB` hex.

const Color kHighlightRed = Color(0x66EF5350);
const Color kHighlightGreen = Color(0x6666BB6A);
const Color kHighlightBlue = Color(0x6642A5F5);

/// Encodes a color as `#AARRGGBB` for the highlights table.
String highlightColorToHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// Decodes a `#AARRGGBB` (or `#RRGGBB`, alpha assumed 0x66) hex string.
/// Returns null for unparseable values.
Color? highlightColorFromHex(String hex) {
  var s = hex.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = '66$s';
  if (s.length != 8) return null;
  final value = int.tryParse(s, radix: 16);
  return value == null ? null : Color(value);
}

/// Floating action panel shown while ≥1 verse is selected.
///
/// Layout: highlight swatches (R, G, B, custom picker) | Save / Note /
/// Copy / Share | Compare | close.
class VerseActionPanel extends StatelessWidget {
  final ValueChanged<Color> onHighlight;
  final VoidCallback onCustomHighlight;
  final VoidCallback onBookmark;
  final VoidCallback onNote;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onCompare;
  final VoidCallback onClose;

  const VerseActionPanel({
    super.key,
    required this.onHighlight,
    required this.onCustomHighlight,
    required this.onBookmark,
    required this.onNote,
    required this.onCopy,
    required this.onShare,
    required this.onCompare,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ColorSwatch(
              color: kHighlightRed,
              tooltip: 'Highlight red',
              onTap: () => onHighlight(kHighlightRed),
            ),
            _ColorSwatch(
              color: kHighlightGreen,
              tooltip: 'Highlight green',
              onTap: () => onHighlight(kHighlightGreen),
            ),
            _ColorSwatch(
              color: kHighlightBlue,
              tooltip: 'Highlight blue',
              onTap: () => onHighlight(kHighlightBlue),
            ),
            _PanelIconButton(
              icon: Icons.palette_outlined,
              tooltip: 'Custom highlight color',
              onTap: onCustomHighlight,
            ),
            _divider(colorScheme),
            _PanelIconButton(
              icon: Icons.bookmark_border,
              tooltip: 'Save (bookmark)',
              onTap: onBookmark,
            ),
            _PanelIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Note',
              onTap: onNote,
            ),
            _PanelIconButton(
              icon: Icons.copy_outlined,
              tooltip: 'Copy',
              onTap: onCopy,
            ),
            _PanelIconButton(
              icon: Icons.share_outlined,
              tooltip: 'Share',
              onTap: onShare,
            ),
            _divider(colorScheme),
            _PanelIconButton(
              icon: Icons.view_column_outlined,
              tooltip: 'Compare',
              onTap: onCompare,
            ),
            _divider(colorScheme),
            _PanelIconButton(
              icon: Icons.close,
              tooltip: 'Clear selection',
              onTap: onClose,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(ColorScheme colorScheme) => Container(
        width: 1,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: colorScheme.outlineVariant,
      );
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                // Show the swatch fully opaque so it reads clearly.
                color: color.withValues(alpha: 1),
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.outline),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _PanelIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 22),
        onPressed: onTap,
      ),
    );
  }
}

/// Dialog with a fixed grid of material shades; resolves to the chosen
/// highlight color (preset alpha applied), or null when dismissed.
/// No color-picker dependency — pub is intentionally untouched.
Future<Color?> showHighlightColorPickerDialog(BuildContext context) {
  const swatches = <MaterialColor>[
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.blueGrey,
    Colors.grey,
  ];
  const shades = <int>[300, 500, 700];

  return showDialog<Color>(
    context: context,
    builder: (dialogContext) {
      final colorScheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: const Text('Highlight color'),
        content: SizedBox(
          width: 6 * 44,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final swatch in swatches)
                for (final shade in shades)
                  InkWell(
                    onTap: () => Navigator.of(dialogContext).pop(
                      // Same translucency as the presets so text stays
                      // legible over the highlight.
                      swatch[shade]!.withValues(alpha: 0.4),
                    ),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: swatch[shade],
                        shape: BoxShape.circle,
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                    ),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}
