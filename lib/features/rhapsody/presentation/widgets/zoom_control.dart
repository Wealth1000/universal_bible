import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/features/rhapsody/application/rhapsody_zoom_provider.dart';

/// Floating zoom control for the Rhapsody reading screen. Sits in the
/// bottom-right corner, collapses to a single FAB-style button when idle so
/// it doesn't compete with the reading, and expands to reveal a horizontal
/// slider with - / + buttons on tap.
///
/// The slider value is the [rhapsodyZoomProvider] state, so changes apply
/// live to the surrounding reading column and persist across sessions.
class RhapsodyZoomControl extends ConsumerStatefulWidget {
  const RhapsodyZoomControl({super.key});

  @override
  ConsumerState<RhapsodyZoomControl> createState() =>
      _RhapsodyZoomControlState();
}

class _RhapsodyZoomControlState extends ConsumerState<RhapsodyZoomControl> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final zoom = ref.watch(rhapsodyZoomProvider);

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _expanded
            ? _buildExpanded(theme, colorScheme, zoom)
            : _buildCollapsed(theme, colorScheme),
      ),
    );
  }

  Widget _buildCollapsed(ThemeData theme, ColorScheme colorScheme) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _toggle,
      child: Tooltip(
        message: 'Adjust text size',
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.text_fields_rounded,
            size: 20,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildExpanded(ThemeData theme, ColorScheme colorScheme, double zoom) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Smaller text',
          onPressed: zoom <= RhapsodyZoomNotifier.minZoom
              ? null
              : () => ref.read(rhapsodyZoomProvider.notifier).decrement(),
          icon: Icon(
            Icons.text_decrease_rounded,
            size: 18,
            color: zoom <= RhapsodyZoomNotifier.minZoom
                ? colorScheme.onSurface.withValues(alpha: 0.3)
                : colorScheme.onSurface,
          ),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        SizedBox(
          width: 160,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: zoom,
              min: RhapsodyZoomNotifier.minZoom,
              max: RhapsodyZoomNotifier.maxZoom,
              onChanged: (v) => ref.read(rhapsodyZoomProvider.notifier).set(v),
              activeColor: colorScheme.primary,
              inactiveColor: colorScheme.outlineVariant,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Larger text',
          onPressed: zoom >= RhapsodyZoomNotifier.maxZoom
              ? null
              : () => ref.read(rhapsodyZoomProvider.notifier).increment(),
          icon: Icon(
            Icons.text_increase_rounded,
            size: 18,
            color: zoom >= RhapsodyZoomNotifier.maxZoom
                ? colorScheme.onSurface.withValues(alpha: 0.3)
                : colorScheme.onSurface,
          ),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        const SizedBox(width: 2),
        Tooltip(
          message: zoom == RhapsodyZoomNotifier.defaultZoom
              ? 'Close'
              : 'Reset to default',
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: zoom == RhapsodyZoomNotifier.defaultZoom
                ? _toggle
                : () => ref.read(rhapsodyZoomProvider.notifier).reset(),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                zoom == RhapsodyZoomNotifier.defaultZoom
                    ? Icons.close_rounded
                    : Icons.refresh_rounded,
                size: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Wraps [child] in a [Stack] that places the zoom control in the bottom-right
/// corner with safe-area + content padding. Use at the screen level so the
/// control floats over the scrolling content without participating in scroll.
class RhapsodyZoomStack extends StatelessWidget {
  const RhapsodyZoomStack({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(child: RhapsodyZoomControl()),
        ),
      ],
    );
  }
}
