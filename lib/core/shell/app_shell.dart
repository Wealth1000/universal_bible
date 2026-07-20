import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/sidebar_provider.dart';

/// Unified app shell: persistent NavigationRail on desktop (>= 768px), bottom
/// navigation bar on narrow layouts. Pages rendered inside a ShellRoute must
/// NOT bring their own navigation rail / bottom bar.
class AppShell extends StatelessWidget {
  final String currentPath;
  final Widget child;

  const AppShell({super.key, required this.currentPath, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(currentPath: currentPath),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNavBar(currentPath: currentPath),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? route; // null = not implemented yet

  const _NavItem(this.icon, this.selectedIcon, this.label, this.route);
}

const _mainItems = [
  _NavItem(Icons.menu_book_outlined, Icons.menu_book, 'Bible', '/reader'),
  _NavItem(Icons.search, Icons.search, 'Search', '/search'),
  _NavItem(Icons.bookmark_outline, Icons.bookmark, 'Bookmarks', null),
  _NavItem(Icons.sticky_note_2_outlined, Icons.sticky_note_2, 'Notes', null),
];

const _settingsItem = _NavItem(
  Icons.settings_outlined,
  Icons.settings,
  'Settings',
  '/settings',
);

void _navigate(BuildContext context, _NavItem item, String currentPath) {
  final route = item.route;
  if (route == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.label} is coming soon.'),
        duration: const Duration(seconds: 2),
      ),
    );
    return;
  }
  if (route != currentPath) context.go(route);
}

// --- Desktop sidebar (NavigationRail) ---
class _Sidebar extends ConsumerWidget {
  final String currentPath;

  const _Sidebar({required this.currentPath});

  static const _allItems = [..._mainItems, _settingsItem];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final collapsed = ref.watch(sidebarCollapsedProvider);

    // Find the index of the currently active destination (if any).
    // /translations is reached from Settings, so it keeps Settings active.
    final effectivePath = currentPath == '/translations'
        ? _settingsItem.route
        : currentPath;
    var selectedIndex = _allItems.indexWhere((i) => i.route == effectivePath);
    if (selectedIndex < 0) selectedIndex = 0;

    return Material(
      color: colorScheme.surfaceContainerLow,
      child: SafeArea(
        right: false,
        child: NavigationRail(
          // Expanded: 80px is enough for "Translations" / "Bookmarks" /
          // "Settings" to render without being clipped, even with the
          // always-visible label. Collapsed: icons only, narrow.
          minWidth: collapsed ? 56 : 80,
          minExtendedWidth: 80,
          extended: false,
          labelType: collapsed
              ? NavigationRailLabelType.none
              : NavigationRailLabelType.all,
          selectedIndex: selectedIndex,
          backgroundColor: colorScheme.surfaceContainerLow,
          indicatorColor: colorScheme.secondaryContainer,
          selectedIconTheme: IconThemeData(
            color: colorScheme.onSecondaryContainer,
          ),
          unselectedIconTheme: IconThemeData(
            color: colorScheme.onSurfaceVariant,
          ),
          selectedLabelTextStyle: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSecondaryContainer,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelTextStyle: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
          leading: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 36,
                  height: 36,
                ),
              ),
              IconButton(
                icon: Icon(
                  collapsed ? Icons.chevron_right : Icons.chevron_left,
                  color: colorScheme.onSurfaceVariant,
                ),
                tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                onPressed: () =>
                    ref.read(sidebarCollapsedProvider.notifier).toggle(),
              ),
            ],
          ),
          destinations: [
            for (final item in _allItems)
              NavigationRailDestination(
                icon: collapsed
                    ? Tooltip(message: item.label, child: Icon(item.icon))
                    : Icon(item.icon),
                selectedIcon: collapsed
                    ? Tooltip(
                        message: item.label,
                        child: Icon(item.selectedIcon),
                      )
                    : Icon(item.selectedIcon),
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

// --- Mobile bottom navigation ---
class _BottomNavBar extends StatelessWidget {
  final String currentPath;

  const _BottomNavBar({required this.currentPath});

  static const _items = [
    _NavItem(Icons.menu_book_outlined, Icons.menu_book, 'Bible', '/reader'),
    _NavItem(Icons.search, Icons.search, 'Search', null),
    _NavItem(Icons.bookmark_outline, Icons.bookmark, 'Bookmarks', null),
    _NavItem(Icons.sticky_note_2_outlined, Icons.sticky_note_2, 'Notes', null),
    _settingsItem,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final item in _items)
                _BottomNavItem(
                  item: item,
                  selected: item.route == currentPath,
                  onTap: () => _navigate(context, item, currentPath),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colorScheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? item.selectedIcon : item.icon, color: color),
            Text(
              item.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
