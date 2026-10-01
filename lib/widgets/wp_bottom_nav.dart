import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';

class WPBottomNav extends StatelessWidget {
  const WPBottomNav({super.key, required this.currentPath});

  final String currentPath;

  static const _items = [
    _NavItem('Home', Icons.home_rounded, '/home'),
    _NavItem('Explore', Icons.explore_outlined, '/explore'),
    _NavItem('Feed', Icons.newspaper_rounded, '/feed'),
    _NavItem('Magazine', Icons.menu_book_rounded, '/magazine'),
    _NavItem('Profile', Icons.person_outline_rounded, '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final activePath = _activePathFor(currentPath);
    final index = _items.indexWhere((item) => activePath.startsWith(item.path));
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: index < 0 ? 0 : index,
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.copper,
      unselectedItemColor: AppColors.muted,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      elevation: 8,
      onTap: (value) => context.go(_items[value].path),
      items: [
        for (final item in _items)
          BottomNavigationBarItem(icon: Icon(item.icon), label: item.label),
      ],
    );
  }

  String _activePathFor(String path) {
    if (path.startsWith('/article')) return '/feed';
    if (path.startsWith('/magazine')) return '/magazine';
    if (path == '/search' ||
        path == '/videos' ||
        path.startsWith('/video') ||
        path == '/events') {
      return '/explore';
    }
    if (path == '/bookmarks' ||
        path == '/downloads' ||
        path == '/wallpapers' ||
        path == '/subscribe' ||
        path == '/preferences' ||
        path == '/contact' ||
        path == '/grow-with-us' ||
        path == '/about' ||
        path == '/group-media' ||
        path == '/clients') {
      return '/profile';
    }
    return path;
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}
