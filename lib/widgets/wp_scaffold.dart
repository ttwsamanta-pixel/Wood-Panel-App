import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import 'wp_app_bar.dart';
import 'wp_bottom_nav.dart';
import 'wp_logo.dart';

class WPScaffold extends StatelessWidget {
  const WPScaffold({
    super.key,
    required this.child,
    this.showBack = false,
    this.title,
    this.showBottomNav = true,
    this.showNotifications = true,
  });

  final Widget child;
  final bool showBack;
  final String? title;
  final bool showBottomNav;
  final bool showNotifications;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const _WPDrawer(),
      appBar: WPAppBar(
        showBack: showBack,
        title: title,
        showNotifications: showNotifications,
      ),
      body: SafeArea(top: false, child: child),
      bottomNavigationBar: showBottomNav
          ? WPBottomNav(currentPath: GoRouterState.of(context).uri.path)
          : null,
    );
  }
}

class _WPDrawer extends StatelessWidget {
  const _WPDrawer();

  static const _items = [
    _DrawerItem('Home', Icons.home_rounded, '/home'),
    _DrawerItem('Explore', Icons.explore_outlined, '/explore'),
    _DrawerItem('Feed', Icons.newspaper_rounded, '/feed'),
    _DrawerItem('Magazine', Icons.menu_book_rounded, '/magazine'),
    _DrawerItem('Videos', Icons.play_circle_outline_rounded, '/videos'),
    _DrawerItem('Bookmarks', Icons.bookmark_border_rounded, '/bookmarks'),
    _DrawerItem('Downloads', Icons.download_rounded, '/downloads'),
    _DrawerItem('Wallpapers', Icons.wallpaper_rounded, '/wallpapers'),
    _DrawerItem('Events', Icons.event_rounded, '/events'),
    _DrawerItem('Newsletter', Icons.mark_email_read_rounded, '/newsletter'),
    _DrawerItem('Subscribe', Icons.workspace_premium_rounded, '/subscribe'),
    _DrawerItem('Grow With Us', Icons.handshake_rounded, '/grow-with-us'),
    _DrawerItem('Contact Us', Icons.mail_outline_rounded, '/contact'),
    _DrawerItem('About Us', Icons.info_outline_rounded, '/about'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Align(alignment: Alignment.centerLeft, child: WPLogo()),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final item in _items)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        item.icon,
                        color: currentPath.startsWith(item.path)
                            ? AppColors.copper
                            : AppColors.muted,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          color: currentPath.startsWith(item.path)
                              ? AppColors.copper
                              : AppColors.ink,
                          fontWeight: currentPath.startsWith(item.path)
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go(item.path);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem {
  const _DrawerItem(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}
