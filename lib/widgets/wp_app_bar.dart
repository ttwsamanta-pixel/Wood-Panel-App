import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import 'wp_logo.dart';

class WPAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WPAppBar({
    super.key,
    this.showBack = false,
    this.title,
    this.showNotifications = true,
  });

  final bool showBack;
  final String? title;
  final bool showNotifications;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      leading: IconButton(
        tooltip: 'Menu',
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
      ),
      titleSpacing: 0,
      title: const SizedBox.shrink(),
      flexibleSpace: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 166),
            child: const WPLogo(height: 36),
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search_rounded),
          onPressed: () => context.push('/search'),
        ),
        if (showNotifications)
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded),
            color: AppColors.ink,
            onPressed: () {},
          ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1),
      ),
    );
  }
}
