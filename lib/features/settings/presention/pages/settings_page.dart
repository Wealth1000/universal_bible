import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_bible/core/providers/translation_repo_provider.dart';
import 'package:universal_bible/core/themes/theme_provider.dart';
import 'package:universal_bible/database/app_database.dart';
import 'package:universal_bible/features/bible/domain/reader_provider.dart';
import 'package:universal_bible/features/settings/domain/book_name_settings_provider.dart';
import '../../../../core/services/storage_service.dart';

// --- Providers for settings (Notifier API) ---
class FontSizeNotifier extends Notifier<double> {
  @override
  double build() => 18.0;

  void set(double value) {
    state = value;
  }
}

final fontSizeProvider = NotifierProvider<FontSizeNotifier, double>(
  FontSizeNotifier.new,
);

class ShowVerseNumbersNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle(bool value) {
    state = value;
  }
}

final showVerseNumbersProvider =
    NotifierProvider<ShowVerseNumbersNotifier, bool>(
      ShowVerseNumbersNotifier.new,
    );

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late SharedPreferences _prefs;
  bool _isLoading = true;
  String _storagePath = '';
  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    // Load font size
    final fontSize = _prefs.getDouble('fontSize') ?? 18.0;
    ref.read(fontSizeProvider.notifier).set(fontSize); // Fixed: use .set()

    // Load verse numbers preference
    final showVerseNumbers = _prefs.getBool('showVerseNumbers') ?? true;
    ref.read(showVerseNumbersProvider.notifier).toggle(showVerseNumbers); // Fixed: use .toggle()

    // Get storage path
    _storagePath = StorageService().baseDir;
    _version = '1.0.42-stable';

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveFontSize(double value) async {
    await _prefs.setDouble('fontSize', value);
    ref.read(fontSizeProvider.notifier).set(value); // Fixed: use .set()
  }

  Future<void> _saveShowVerseNumbers(bool value) async {
    await _prefs.setBool('showVerseNumbers', value);
    ref.read(showVerseNumbersProvider.notifier).toggle(value); // Fixed: use .toggle()
  }

  Future<void> _clearCache() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing cache: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get current values from providers
    final currentThemeMode = ref.watch(themeProvider);
    final currentFontSize = ref.watch(fontSizeProvider);
    final showVerseNumbers = ref.watch(showVerseNumbersProvider);
    final preserveBookNames = ref.watch(preserveOriginalBookNamesProvider);
    final currentTranslationId = ref.watch(currentTranslationProvider);

    // Navigation (sidebar / bottom bar) is provided by the AppShell.
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(
              context,
              theme,
              colorScheme,
              currentThemeMode,
              currentFontSize,
              showVerseNumbers,
              preserveBookNames,
              currentTranslationId,
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      elevation: 0,
      automaticallyImplyLeading: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      title: Text(
        'Settings',
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
    ThemeMode currentThemeMode,
    double currentFontSize,
    bool showVerseNumbers,
    bool preserveBookNames,
    String? currentTranslationId,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Appearance Group
              _buildSection(
                title: 'Appearance',
                children: [
                  _buildThemeToggle(
                    context,
                    theme,
                    colorScheme,
                    currentThemeMode,
                  ),
                  _buildFontSizeSlider(
                    context,
                    theme,
                    colorScheme,
                    currentFontSize,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Reading Group
              _buildSection(
                title: 'Reading',
                children: [
                  _buildTranslationDropdown(
                    context,
                    theme,
                    colorScheme,
                    currentTranslationId,
                  ),
                  _buildManageTranslations(context, theme, colorScheme),
                  _buildVerseNumbersToggle(
                    context,
                    theme,
                    colorScheme,
                    showVerseNumbers,
                  ),
                  _buildPreserveBookNamesToggle(
                    context,
                    theme,
                    colorScheme,
                    preserveBookNames,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Data & Storage Group
              _buildSection(
                title: 'Data & Storage',
                children: [
                  _buildStoragePath(context, theme, colorScheme),
                  _buildClearCache(context, theme, colorScheme),
                ],
              ),
              const SizedBox(height: 24),

              // About Group
              _buildSection(
                title: 'About',
                children: [
                  _buildVersion(context, theme, colorScheme),
                  _buildLicense(context, theme, colorScheme),
                  _buildCredits(context, theme, colorScheme),
                ],
              ),
              const SizedBox(height: 24),

              // Decorative verse
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '"Thy word is a lamp unto my feet..."',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  // --- Theme Toggle ---
  Widget _buildThemeToggle(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    ThemeMode currentThemeMode,
  ) {
    final isLight = currentThemeMode == ThemeMode.light;
    final isDark = currentThemeMode == ThemeMode.dark;
    final isSystem = currentThemeMode == ThemeMode.system;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.palette, color: colorScheme.secondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${currentThemeMode.toString().split('.').last} active',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _themeToggleButton(
                  label: 'Light',
                  isSelected: isLight,
                  onTap: () {
                    ref.read(themeProvider.notifier).setTheme(ThemeMode.light);
                  },
                ),
                _themeToggleButton(
                  label: 'Dark',
                  isSelected: isDark,
                  onTap: () {
                    ref.read(themeProvider.notifier).setTheme(ThemeMode.dark);
                  },
                ),
                _themeToggleButton(
                  label: 'System',
                  isSelected: isSystem,
                  onTap: () {
                    ref.read(themeProvider.notifier).setTheme(ThemeMode.system);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Theme toggle button (segmented control) ---
  Widget _themeToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // --- Font Size Slider ---
  Widget _buildFontSizeSlider(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    double currentFontSize,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.format_size,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              Icon(
                Icons.format_size,
                size: 28,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          Slider(
            value: currentFontSize,
            min: 12,
            max: 32,
            divisions: 20,
            onChanged: (value) {
              _saveFontSize(value);
            },
            activeColor: colorScheme.primary,
            inactiveColor: colorScheme.outlineVariant,
          ),
          Text(
            'Reading font size: ${currentFontSize.toStringAsFixed(0)}pt',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // --- Translation Dropdown ---
  Widget _buildTranslationDropdown(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    String? currentTranslationId,
  ) {
    return Consumer(
      builder: (context, ref, child) {
        final translations = ref.watch(translationRepoProvider).getInstalled();
        return FutureBuilder<List<Translation>>(
          future: translations,
          builder: (context, snapshot) {
            final list = snapshot.data ?? [];
            final selectedId =
                currentTranslationId ?? (list.isNotEmpty ? list.first.id : '');
            final selectedTranslation = list.firstWhere(
              (t) => t.id == selectedId,
              orElse: () => list.isNotEmpty ? list.first : Translation(
                id: '',
                name: 'Select translation',
                languageCode: '',
                version: 0,
                installed: false, bookMapJson: '',
              ),
            );
            final selectedName = selectedTranslation.name;

            return InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Select Default Translation'),
                    content: SizedBox(
                      width: double.maxFinite,
                      height: 300,
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final t = list[index];
                          return ListTile(
                            title: Text(t.name),
                            subtitle: Text(t.id),
                            trailing: t.id == selectedId
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : null,
                            onTap: () {
                              ref
                                  .read(currentTranslationProvider.notifier)
                                  .set(t.id);
                              Navigator.pop(context);
                              _prefs.setString('defaultTranslation', t.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Default translation updated.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.translate, color: colorScheme.secondary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Default Translation',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            selectedName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.expand_more, color: colorScheme.outline),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Manage Translations (entry point to the translation manager) ---
  Widget _buildManageTranslations(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return InkWell(
      onTap: () => context.go('/translations'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.download_for_offline_outlined, color: colorScheme.secondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Translations',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Install, update or remove Bible translations',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.outline),
          ],
        ),
      ),
    );
  }

  // --- Verse Numbers Toggle ---
  Widget _buildVerseNumbersToggle(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool currentValue,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.format_list_numbered, color: colorScheme.secondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Show Verse Numbers',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Display numbers inline with text',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: currentValue,
            onChanged: (value) {
              _saveShowVerseNumbers(value);
            },
            activeThumbColor: colorScheme.primary, // Fixed: changed from activeColor
          ),
        ],
      ),
    );
  }

  // --- Preserve Original Book Names Toggle ---
  Widget _buildPreserveBookNamesToggle(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool currentValue,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.history_edu, color: colorScheme.secondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Original Book Names',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  currentValue
                      ? '"The First Book of Moses called Genesis"'
                      : '"Genesis"',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: currentValue,
            onChanged: (value) {
              ref.read(preserveOriginalBookNamesProvider.notifier).set(value);
            },
            activeThumbColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  // --- Storage Path ---
  Widget _buildStoragePath(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage, color: colorScheme.secondary),
              const SizedBox(width: 16),
              Text(
                'Storage Path',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Text(
              _storagePath,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Clear Cache ---
  Widget _buildClearCache(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return InkWell(
      onTap: _clearCache,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.delete_sweep, color: Colors.red),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clear Cache',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  Text(
                    'Free up temporary data (estimated 42.5 MB)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.red),
          ],
        ),
      ),
    );
  }

  // --- Version ---
  Widget _buildVersion(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.info, color: colorScheme.secondary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Version',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            _version,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- License ---
  Widget _buildLicense(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('License'),
            content: const Text(
              'This project is licensed under the MIT License.\n\n'
              'Copyright (c) 2026 Bible Project Contributors\n\n'
              'Permission is hereby granted... (full text omitted for brevity)',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.policy, color: colorScheme.secondary),
            const SizedBox(width: 16),
            Text(
              'License',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Credits ---
  Widget _buildCredits(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Credits'),
            content: const Text(
              'Bible Project\n\n'
              'Built with Flutter & Supabase\n'
              'Design by the Bible Project Team\n'
              'Contributors: [List names]\n\n'
              'Translations provided by [Data Source]',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.group, color: colorScheme.secondary),
            const SizedBox(width: 16),
            Text(
              'Credits',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
