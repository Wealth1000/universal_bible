import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_bible/database/app_database.dart';
import 'package:universal_bible/features/bible/domain/reader_provider.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../bible/data/repositories/translation_repository.dart';


final _translationRepoProvider = Provider<TranslationRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TranslationRepository(db);
});

class TranslationManagerPage extends ConsumerStatefulWidget {
  const TranslationManagerPage({super.key});

  @override
  ConsumerState<TranslationManagerPage> createState() => _TranslationManagerPageState();
}

class _TranslationManagerPageState extends ConsumerState<TranslationManagerPage> {
  bool _isImporting = false;
  List<Translation> _translations = [];

  @override
  void initState() {
    super.initState();
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    final repo = ref.read(_translationRepoProvider);
    final translations = await repo.getInstalled();
    setState(() {
      _translations = translations;
    });
  }

  Future<void> _importTranslation() async {
  setState(() => _isImporting = true);

  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bdat'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) {
      setState(() => _isImporting = false);
      return;
    }

    final repo = ref.read(_translationRepoProvider);
    int successCount = 0;
    int failureCount = 0;

    for (final file in result.files) {
      final filePath = file.path;
      if (filePath == null) continue;

      try {
        await repo.importFromFile(filePath);
        successCount++;
      } catch (e) {
        debugPrint('❌ Failed to import ${file.name}: $e');
        failureCount++;
      }
    }

    // Refresh the list after all imports
    await _loadTranslations();

    // Set first imported as active if any succeeded
    if (successCount > 0) {
      final translations = await repo.getInstalled();
      if (translations.isNotEmpty) {
        ref.read(currentTranslationProvider.notifier).set(translations.first.id);
      }
    }

    // Show summary
    if (mounted) {
      final message = successCount > 0
          ? 'Imported $successCount translation${successCount > 1 ? 's' : ''} successfully.'
          : 'No translations were imported.';
      if (failureCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$message $failureCount failed. Check logs.'),
            backgroundColor: failureCount > 0 && successCount == 0 ? Colors.red : Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('Error during import: $e');
    debugPrint('Stack trace: ${StackTrace.current}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isImporting = false);
    }
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
              foregroundColor: Colors.red,
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
          const SnackBar(
            content: Text('Translation deleted.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting translation: $e'),
            backgroundColor: Colors.red,
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
          content: Text('Active translation changed.'),
          backgroundColor: Colors.green,
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
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? colorScheme.primary : const Color(0xFF2E434C);
    final currentTranslationId = ref.watch(currentTranslationProvider);

    // Get screen size for responsive layout
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context, isDesktop),
      body: Row(
        children: [
          // Desktop Navigation Rail
          if (isDesktop) _DesktopNavigationRail(selectedIndex: 2),
          // Main Content
          Expanded(
            child: _buildContent(
              context,
              theme,
              colorScheme,
              currentTranslationId,
              isDesktop,
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(theme, primaryColor),
      bottomNavigationBar: isDesktop ? null : _BottomNavBar(selectedIndex: 4),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDesktop) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      leading: isDesktop
          ? null
          : IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu),
              color: colorScheme.onSurfaceVariant,
            ),
      title: Text(
        'Translations',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.more_vert),
          color: colorScheme.onSurfaceVariant,
        ),
      ],
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
          Icon(
            Icons.cloud_download,
            size: 64,
            color: colorScheme.outline,
          ),
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
        border: Border.all(
          color: borderColor,
          width: isActive ? 2 : 1,
        ),
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
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Active',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green,
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

// --- Desktop Navigation Rail ---
class _DesktopNavigationRail extends StatelessWidget {
  final int selectedIndex;

  const _DesktopNavigationRail({required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;

    final items = [
      {'icon': Icons.menu_book, 'label': 'Bible', 'route': '/reader'},
      {'icon': Icons.search, 'label': 'Search', 'route': '/search'},
      {'icon': Icons.translate, 'label': 'Translations', 'route': '/translations'},
      {'icon': Icons.bookmark, 'label': 'Bookmarks', 'route': '/bookmarks'},
      {'icon': Icons.sticky_note_2, 'label': 'Notes', 'route': '/notes'},
      {'icon': Icons.download, 'label': 'Downloads', 'route': '/downloads'},
      {'icon': Icons.settings, 'label': 'Settings', 'route': '/settings'},
    ];

    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Image.asset(
              'assets/images/app_logo.png',
              width: 40,
              height: 40,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final isSelected = index == selectedIndex;
                final icon = items[index]['icon'] as IconData;
                final label = items[index]['label'] as String;
                final route = items[index]['route'] as String;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.secondaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: InkWell(
                    onTap: () => context.go(route),
                    borderRadius: BorderRadius.circular(32),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            color: isSelected
                                ? colorScheme.onSecondaryContainer
                                : onSurfaceVariant,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isSelected
                                  ? colorScheme.onSecondaryContainer
                                  : onSurfaceVariant,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'v1.0',
              style: theme.textTheme.labelSmall?.copyWith(
                color: onSurfaceVariant.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Mobile Bottom Navigation ---
class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;

  const _BottomNavBar({required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final items = [
      {'icon': Icons.menu_book, 'label': 'Bible', 'route': '/reader'},
      {'icon': Icons.search, 'label': 'Search', 'route': '/search'},
      {'icon': Icons.bookmark, 'label': 'Bookmarks', 'route': '/bookmarks'},
      {'icon': Icons.sticky_note_2, 'label': 'Notes', 'route': '/notes'},
      {'icon': Icons.settings, 'label': 'Settings', 'route': '/settings'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == selectedIndex;
              final icon = item['icon'] as IconData;
              final label = item['label'] as String;
              final route = item['route'] as String;

              return InkWell(
                onTap: () => context.go(route),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.secondaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: isSelected
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? colorScheme.onSecondaryContainer
                              : colorScheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}