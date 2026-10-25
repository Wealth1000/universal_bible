import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// App shell: persistent NavigationRail sidebar. Pages rendered inside a
/// ShellRoute must NOT bring their own navigation rail.
class AppShell extends StatelessWidget {
  final String currentPath;
  final Widget child;

  const AppShell({super.key, required this.currentPath, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(currentPath: currentPath),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;

  const _NavItem(this.icon, this.selectedIcon, this.label, this.route);
}

const _mainItems = [
  _NavItem(Icons.menu_book_outlined, Icons.menu_book, 'Bible', '/reader'),
  _NavItem(
    Icons.auto_stories_outlined,
    Icons.auto_stories,
    'Rhapsody',
    '/rhapsody',
  ),
  _NavItem(Icons.search, Icons.search, 'Search', '/search'),
  _NavItem(Icons.bookmark_outline, Icons.bookmark, 'Bookmarks', '/bookmarks'),
  _NavItem(Icons.sticky_note_2_outlined, Icons.sticky_note_2, 'Notes', '/notes'),
];

const _settingsItem = _NavItem(
  Icons.settings_outlined,
  Icons.settings,
  'Settings',
  '/settings',
);

void _navigate(BuildContext context, _NavItem item, String currentPath) {
  if (item.route != currentPath) context.go(item.route);
}

// --- Desktop sidebar (NavigationRail) ---
// Icons-only with tooltips; the UI is self-explanatory, no expanded state.
class _Sidebar extends StatelessWidget {
  final String currentPath;

  const _Sidebar({required this.currentPath});

  static const _allItems = [..._mainItems, _settingsItem];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Find the index of the currently active destination (if any).
    // /translations is reached from Settings, so it keeps Settings active.
    final effectivePath = currentPath == '/translations'
        ? _settingsItem.route
        : currentPath;
    var selectedIndex = _allItems.indexWhere((i) => i.route == effectivePath);
    if (selectedIndex < 0) selectedIndex = 0;

    return Material(
      // Chrome surface — the paper/chrome color shift is the separation;
      // no border (UI_OVERHAUL §3.1).
      color: colorScheme.surfaceContainerLow,
      child: SafeArea(
        right: false,
        child: NavigationRail(
          minWidth: 56,
          labelType: NavigationRailLabelType.none,
          selectedIndex: selectedIndex,
          backgroundColor: colorScheme.surfaceContainerLow,
          // Active = ink pill (12% alpha), icon+label in ink.
          indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
          indicatorShape: const StadiumBorder(),
          selectedIconTheme: IconThemeData(color: colorScheme.primary),
          unselectedIconTheme: IconThemeData(
            color: colorScheme.onSurfaceVariant,
          ),
          leading: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Image.asset(
              'assets/images/app_logo.png',
              width: 36,
              height: 36,
            ),
          ),
          destinations: [
            for (final item in _allItems)
              NavigationRailDestination(
                icon: Tooltip(message: item.label, child: Icon(item.icon)),
                selectedIcon: Tooltip(
                  message: item.label,
                  child: Icon(item.selectedIcon),
                ),
                label: Text(item.label),
              ),
          ],
          onDestinationSelected: (index) {
            _navigate(context, _allItems[index], currentPath);
          },
        ),
      ),
    );
  }
}
