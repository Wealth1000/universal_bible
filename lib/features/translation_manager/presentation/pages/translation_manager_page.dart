import 'package:flutter/material.dart';
import 'package:universal_bible/core/design/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_bible/core/providers/translation_repo_provider.dart';
import 'package:universal_bible/database/app_database.dart';
import 'package:universal_bible/features/bible/domain/reader_provider.dart';

class TranslationManagerPage extends ConsumerStatefulWidget {
  const TranslationManagerPage({super.key});

  @override
  ConsumerState<TranslationManagerPage> createState() =>
      _TranslationManagerPageState();
}

enum _ImportStatus { pending, importing, done, failed }

class _ImportJob {
  final String fileName;
  _ImportStatus status = _ImportStatus.pending;

  _ImportJob(this.fileName);
}

class _TranslationManagerPageState
    extends ConsumerState<TranslationManagerPage> {
  bool _isImporting = false;

  /// Non-null while a batch import is running (and briefly after, until
  /// dismissed). Drives the progress card.
  List<_ImportJob>? _importJobs;
  List<Translation> _translations = [];

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    final repo = ref.read(translationRepoProvider);
    final translations = await repo.getInstalled();
    setState(() {
      _translations = translations;
    });
  }

  Future<void> _importTranslation() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bdat'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;

    final files = result.files.where((f) => f.path != null).toList();
    final jobs = [for (final f in files) _ImportJob(f.name)];

    setState(() {
      _isImporting = true;
      _importJobs = jobs;
    });

    final repo = ref.read(translationRepoProvider);
    final hadTranslations = _translations.isNotEmpty;
    int successCount = 0;

    // Sequential on purpose: parsing already runs on a background isolate,
    // and the DB write is the serial part anyway. The list refreshes after
    // each file so imported translations are readable immediately.
    for (var i = 0; i < files.length; i++) {
      setState(() => jobs[i].status = _ImportStatus.importing);
      try {
        await repo.importFromFile(files[i].path!);
        successCount++;
        if (!mounted) return;
        setState(() => jobs[i].status = _ImportStatus.done);
        await _loadTranslations();
        // Make the first successful import active right away if the user
        // had nothing installed, so they can start reading while the rest
        // load.
        if (!hadTranslations &&
            ref.read(currentTranslationProvider) == null &&
            _translations.isNotEmpty) {
          ref
              .read(currentTranslationProvider.notifier)
              .set(_translations.first.id);
        }
      } catch (e) {
        debugPrint('❌ Failed to import ${files[i].name}: $e');
        if (!mounted) return;
        setState(() => jobs[i].status = _ImportStatus.failed);
      }
    }

    if (!mounted) return;
    final failureCount = jobs
        .where((j) => j.status == _ImportStatus.failed)
        .length;
    setState(() {
      _isImporting = false;
      // Keep the card visible if anything failed so the user can see which;
      // otherwise it disappears — the refreshed list is the confirmation.
      if (failureCount == 0) _importJobs = null;
    });
    if (failureCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$successCount imported, $failureCount failed. Check logs.',
          ),
          backgroundColor: AppColors.danger(Theme.of(context).brightness),
        ),
      );
    }
  }

  Future<void> _deleteTranslation(String id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Translation'),
        content: const Text(
          'This will permanently delete the translation and all its verses. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger(Theme.of(context).brightness),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      // TODO: Implement delete in TranslationRepository
      // await repo.deleteTranslation(id);
      await _loadTranslations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Translation deleted.'),
            backgroundColor: AppColors.danger(Theme.of(context).brightness),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting translation: $e'),
            backgroundColor: AppColors.danger(Theme.of(context).brightness),
          ),
        );
      }
    }
  }

  Future<void> _activateTranslation(String id) async {
    ref.read(currentTranslationProvider.notifier).set(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Active translation changed.'),
          backgroundColor: AppColors.success(Theme.of(context).brightness),
        ),
      );
      // Navigate to reader
      context.go('/reader');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;
    final currentTranslationId = ref.watch(currentTranslationProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;

    // Navigation (sidebar / bottom bar) is provided by the AppShell.
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _buildContent(
        context,
        theme,
        colorScheme,
        currentTranslationId,
        isDesktop,
      ),
      floatingActionButton: _buildFAB(theme, primaryColor),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      elevation: 0,
      automaticallyImplyLeading: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      // Reached from Settings (no sidebar entry of its own), so provide an
      // explicit way back.
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Back to Settings',
        onPressed: () => context.go('/settings'),
      ),
      title: Text(
        'Translations',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    String? currentTranslationId,
    bool isDesktop,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Installed',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your downloaded Scripture translations for offline reading.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Import progress card
          if (_importJobs != null)
            _ImportProgressCard(
              jobs: _importJobs!,
              onDismiss: _isImporting
                  ? null
                  : () => setState(() => _importJobs = null),
            ),

          // Translation List
          Expanded(
            child: _translations.isEmpty
                ? _buildEmptyState(theme, colorScheme)
                : ListView.builder(
                    itemCount: _translations.length,
                    itemBuilder: (context, index) {
                      final translation = _translations[index];
                      final isActive = translation.id == currentTranslationId;
                      return _TranslationCard(
                        translation: translation,
                        isActive: isActive,
                        onActivate: () => _activateTranslation(translation.id),
                        onDelete: () => _deleteTranslation(translation.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_download, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'No translations installed yet.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the Import button to add a translation.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(ThemeData theme, Color primaryColor) {
    return FloatingActionButton.extended(
      onPressed: _isImporting ? null : _importTranslation,
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      icon: _isImporting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.download),
      label: Text(_isImporting ? 'Importing...' : 'Import'),
    );
  }
}

// --- Import progress card ---
class _ImportProgressCard extends StatelessWidget {
  final List<_ImportJob> jobs;

  /// Null while the batch is still running (card can't be dismissed).
  final VoidCallback? onDismiss;

  const _ImportProgressCard({required this.jobs, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final doneCount = jobs
        .where(
          (j) =>
              j.status == _ImportStatus.done ||
              j.status == _ImportStatus.failed,
        )
        .length;
    final running = onDismiss == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  running
                      ? 'Importing $doneCount of ${jobs.length}…'
                      : 'Import finished',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!running)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Dismiss',
                  onPressed: onDismiss,
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: jobs.isEmpty ? 0 : doneCount / jobs.length,
            ),
          ),
          const SizedBox(height: 12),
          // Cap the per-file list so a large batch (25+ files) scrolls inside
          // the card instead of overflowing the page column.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final job in jobs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: switch (job.status) {
                              _ImportStatus.pending => Icon(
                                Icons.schedule,
                                size: 16,
                                color: colorScheme.outline,
                              ),
                              _ImportStatus.importing =>
                                const CircularProgressIndicator(strokeWidth: 2),
                              _ImportStatus.done => Icon(
                                Icons.check_circle,
                                size: 16,
                                color: AppColors.success(theme.brightness),
                              ),
                              _ImportStatus.failed => Icon(
                                Icons.error,
                                size: 16,
                                color: AppColors.danger(theme.brightness),
                              ),
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              job.fileName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: job.status == _ImportStatus.failed
                                    ? AppColors.danger(theme.brightness)
                                    : colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Translation Card Widget ---
class _TranslationCard extends StatelessWidget {
  final Translation translation;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  const _TranslationCard({
    required this.translation,
    required this.isActive,
    required this.onActivate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final cardColor = isActive
        ? colorScheme.surface
        : colorScheme.surfaceContainerLow;
    final borderColor = isActive
        ? colorScheme.primary
        : colorScheme.outlineVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor, width: isActive ? 2 : 1),
        borderRadius: BorderRadius.circular(32),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isActive ? Icons.auto_stories : Icons.translate,
              color: isActive
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          // Translation info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translation.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${translation.languageCode} - v${translation.version}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isActive)
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Active',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Installed',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          Row(
            children: [
              if (!isActive)
                TextButton(
                  onPressed: onActivate,
                  style: TextButton.styleFrom(
                    backgroundColor: colorScheme.secondaryContainer,
                    foregroundColor: colorScheme.onSecondaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  child: const Text('Activate'),
                ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete),
                color: colorScheme.onSurfaceVariant,
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
