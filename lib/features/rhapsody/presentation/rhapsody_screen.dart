import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/core/design/app_tokens.dart';
import 'package:universal_bible/features/rhapsody/application/devotional_body_parser.dart';
import 'package:universal_bible/features/rhapsody/application/rhapsody_providers.dart';
import 'package:universal_bible/features/rhapsody/application/rhapsody_zoom_provider.dart';
import 'package:universal_bible/features/rhapsody/domain/devotional.dart';
import 'package:universal_bible/features/rhapsody/presentation/rhapsody_layout.dart';
import 'package:universal_bible/features/rhapsody/presentation/widgets/scripture_reference_reveal.dart';
import 'package:universal_bible/features/rhapsody/presentation/widgets/zoom_control.dart';

/// Today's Rhapsody devotional, read from Supabase. Replaces the former
/// placeholder. Keeps the original screen contract: [embedded] renders just
/// the reading body (for the desktop shell); standalone renders its own
/// scaffold (mobile app bar, or a desktop sidebar + content split).
class RhapsodyScreen extends ConsumerWidget {
  const RhapsodyScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wide = useDesktopLayoutForContext(context);
    final devotionalAsync = ref.watch(todayDevotionalProvider);

    final body = devotionalAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          _ErrorState(onRetry: () => ref.invalidate(todayDevotionalProvider)),
      data: (devotional) => devotional == null
          ? const _EmptyState()
          : _DevotionalReader(devotional: devotional, wide: wide),
    );

    // The floating zoom control is part of the reading experience and should
    // be available whether the screen is embedded in the desktop shell or
    // rendered as its own scaffold. Stack it over the body either way.
    if (embedded) return RhapsodyZoomStack(child: body);

    if (wide) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: RhapsodyZoomStack(child: body),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Rhapsody')),
      body: RhapsodyZoomStack(child: body),
    );
  }
}

/// The reading column: date, title, illustration slot, body, confession, and
/// the three scripture reading-plan sections. Width is constrained and centred
/// so it stays readable on tablet/desktop. All text sizes are scaled by the
/// Rhapsody zoom multiplier (see [rhapsodyZoomProvider]).
class _DevotionalReader extends ConsumerWidget {
  const _DevotionalReader({required this.devotional, required this.wide});

  final Devotional devotional;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tablet = isTabletLayout(context);
    final zoom = ref.watch(rhapsodyZoomProvider);
    final maxWidth = !wide ? double.infinity : (tablet ? 720.0 : 820.0);
    final hPad = wide ? (tablet ? 24.0 : 28.0) : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, wide ? 24 : 16, hPad, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dateLabel(devotional.date).toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  fontSize:
                      (theme.textTheme.labelMedium?.fontSize ?? 12) * zoom,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                devotional.title,
                style: TextStyle(
                  fontFamily: AppFonts.scripture,
                  fontSize: (wide ? 30.0 : 25.0) * zoom,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 18),
              _IllustrationSlot(imageUrl: devotional.imageUrl),
              const SizedBox(height: 22),
              _DevotionalBody(
                paragraphs: devotional.bodyParagraphs,
                zoom: zoom,
              ),
              if (devotional.confession.trim().isNotEmpty) ...[
                const SizedBox(height: 24),
                _ConfessionCard(text: devotional.confession, zoom: zoom),
              ],
              if (devotional.hasReadingPlan) ...[
                const SizedBox(height: 28),
                _ReadingPlan(devotional: devotional, zoom: zoom),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Reserved 16:9 space for the daily illustration. The image is lazy-loaded
/// with a graceful placeholder while loading / on error, so the layout shows
/// how it would look without blocking on the network.
class _IllustrationSlot extends StatelessWidget {
  const _IllustrationSlot({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget placeholder([String? label]) => Container(
      alignment: Alignment.center,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 34,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          if (label != null) ...[
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                letterSpacing: 1,
              ),
            ),
          ],
        ],
      ),
    );

    final url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: url == null
              ? placeholder('ILLUSTRATION')
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : placeholder(),
                  errorBuilder: (context, _, _) => placeholder('ILLUSTRATION'),
                ),
        ),
      ),
    );
  }
}

/// Renders parsed devotional paragraphs, styling inline scripture references
/// as tappable rubric spans (see [showScriptureReveal]). Stateful so the tap
/// recognizers can be disposed.
class _DevotionalBody extends StatefulWidget {
  const _DevotionalBody({required this.paragraphs, required this.zoom});

  final List<DevotionalParagraph> paragraphs;
  final double zoom;

  @override
  State<_DevotionalBody> createState() => _DevotionalBodyState();
}

class _DevotionalBodyState extends State<_DevotionalBody> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readingColor = theme.colorScheme.onSurface.withValues(alpha: 0.92);
    final baseStyle = TextStyle(
      fontFamily: AppFonts.scripture,
      fontSize: 16.5 * widget.zoom,
      height: 1.62,
      color: readingColor,
    );

    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final visible = widget.paragraphs
        .where((p) => !p.isEmpty)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              children: [
                for (final span in visible[i].spans) _span(span, baseStyle),
              ],
            ),
          ),
        ],
      ],
    );
  }

  InlineSpan _span(DevotionalSpan span, TextStyle base) {
    if (span.isScripture) {
      final rubric = AppColors.wordsOfChrist(Theme.of(context).brightness);
      final recognizer = TapGestureRecognizer()
        ..onTap = () => showScriptureReveal(context, span.scriptureRef!);
      _recognizers.add(recognizer);
      return TextSpan(
        text: span.text,
        recognizer: recognizer,
        style: base.copyWith(
          color: rubric,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: rubric.withValues(alpha: 0.5),
        ),
      );
    }
    return TextSpan(
      text: span.text,
      style: base.copyWith(
        fontWeight: span.bold ? FontWeight.w700 : FontWeight.w400,
        fontStyle: span.italic ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }
}

class _ConfessionCard extends StatelessWidget {
  const _ConfessionCard({required this.text, required this.zoom});

  final String text;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONFESSION',
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1.6,
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w800,
              fontSize: (theme.textTheme.labelLarge?.fontSize ?? 14) * zoom,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              fontFamily: AppFonts.scripture,
              fontSize: 15.5 * zoom,
              height: 1.55,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

/// The three scripture reading lists, each a labelled block of tappable chips.
class _ReadingPlan extends StatelessWidget {
  const _ReadingPlan({required this.devotional, required this.zoom});

  final Devotional devotional;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReadingSection(
          title: 'Further Study',
          refs: devotional.furtherStudy,
          zoom: zoom,
        ),
        _ReadingSection(
          title: '1-Year Bible Reading Plan',
          refs: devotional.oneYearBible,
          zoom: zoom,
        ),
        _ReadingSection(
          title: '2-Year Bible Reading Plan',
          refs: devotional.twoYearBible,
          zoom: zoom,
        ),
      ],
    );
  }
}

class _ReadingSection extends StatelessWidget {
  const _ReadingSection({
    required this.title,
    required this.refs,
    required this.zoom,
  });

  final String title;
  final List<String> refs;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    if (refs.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1.4,
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w800,
              fontSize: (theme.textTheme.labelLarge?.fontSize ?? 14) * zoom,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ref in refs) ScriptureRefChip(reference: ref),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              "Couldn't load today's devotional.",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 40,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              'No devotional available yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _dateLabel(DateTime d) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdays[d.weekday - 1]} · ${d.day} ${months[d.month - 1]} ${d.year}';
}
