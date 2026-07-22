import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/features/rhapsody/application/rhapsody_daily_content.dart';
import 'package:universal_bible/features/rhapsody/presentation/rhapsody_layout.dart';

/// Placeholder main pane for future Rhapsody (devotion / reading tools).
class RhapsodyPlaceholderScreen extends ConsumerWidget {
  const RhapsodyPlaceholderScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wide = useDesktopLayoutForContext(context);
    final daily = ref.watch(rhapsodyDailyContentProvider);

    final body = wide
        ? _wideBody(context, daily)
        : _compactBody(context, daily);

    if (embedded) {
      return body;
    }

    if (wide) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: body,
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Rhapsody')),
      body: body,
    );
  }

  /// Desktop + tablet: single reading column, no archive list or mock chrome.
  Widget _wideBody(BuildContext context, RhapsodyDailyContent daily) {
    final theme = Theme.of(context);
    final tablet = isTabletLayout(context);
    final maxContentWidth = tablet ? 720.0 : 820.0;
    final horizontalPad = tablet ? 24.0 : 28.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPad,
        tablet ? 20 : 24,
        horizontalPad,
        42,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rhapsody',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Today',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                daily.dateLabel.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                daily.title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 22),
              _SectionCard(
                title: 'Scripture Reference',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"${daily.verseText}"',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      daily.verseReference.toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                daily.body,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Confessions',
                child: Text(
                  daily.confession,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactBody(BuildContext context, RhapsodyDailyContent daily) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        Text(
          daily.dateLabel.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          daily.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Reading for today',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outline),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.85,
                ),
                theme.colorScheme.surface.withValues(alpha: 0.9),
              ],
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.auto_stories_outlined,
            color: theme.colorScheme.secondary.withValues(alpha: 0.8),
            size: 38,
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Scripture Reference',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"${daily.verseText}"',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                daily.verseReference.toUpperCase(),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Reading',
          child: Text(
            daily.body,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Confessions',
          child: Text(
            daily.confession,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1.4,
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
