import 'back_to_top.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_drawer.dart';
import 'wp_app_bar.dart';
import 'wp_bottom_nav.dart';
import 'promotional_ads.dart';

class WPScaffold extends StatelessWidget {
  const WPScaffold({
    super.key,
    required this.child,
    this.showBack = false,
    this.title,
    this.showBottomNav = true,
    this.showNotifications = true,
    this.adPageKey = '',
  });

  final Widget child;
  final bool showBack;
  final String? title;
  final bool showBottomNav;
  final bool showNotifications;
  final String adPageKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: WPAppBar(
        showBack: showBack,
        title: title,
        showNotifications: showNotifications,
      ),
      body: SafeArea(
          top: false,
          child: (GoRouterState.of(context).uri.path.startsWith('/article/') ||
                  GoRouterState.of(context)
                      .uri
                      .path
                      .startsWith('/interview/') ||
                  GoRouterState.of(context).uri.path == '/legacy-interview')
              ? BackToTop(child: child)
              : child),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FooterAdvertisement(pageKey: adPageKey),
            if (showBottomNav)
              WPBottomNav(currentPath: GoRouterState.of(context).uri.path),
          ])),
    );
  }
}
