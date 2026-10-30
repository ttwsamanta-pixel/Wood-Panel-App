import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/edition/edition.dart';
import '../core/edition/edition_navigation.dart';

import '../core/theme/app_colors.dart';
import 'wp_logo.dart';

class WPAppBar extends ConsumerWidget implements PreferredSizeWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
            child: Builder(
                builder: (anchorContext) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        final overlay = Overlay.of(context)
                            .context
                            .findRenderObject()! as RenderBox;
                        final anchor =
                            anchorContext.findRenderObject()! as RenderBox;
                        final bottom = anchor
                            .localToGlobal(Offset(0, anchor.size.height),
                                ancestor: overlay)
                            .dy;
                        final width =
                            (overlay.size.width - 32).clamp(0.0, 250.0);
                        final left = (overlay.size.width - width) / 2;
                        final edition = await showMenu<Edition>(
                          context: context,
                          position:
                              RelativeRect.fromLTRB(left, bottom, left, 0),
                          color: Colors.white,
                          surfaceTintColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          constraints: BoxConstraints.tightFor(width: width),
                          items: [
                            for (final edition in [
                              ref.watch(editionProvider),
                              ...Edition.values
                                  .where((e) => e != ref.watch(editionProvider))
                            ])
                              PopupMenuItem(
                                  value: edition,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 10),
                                    decoration: BoxDecoration(
                                      color:
                                          ref.watch(editionProvider) == edition
                                              ? ref
                                                  .watch(activeConfigProvider)
                                                  .primary
                                                  .withValues(alpha: .07)
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(children: [
                                      SizedBox(
                                          width: 100,
                                          height: 44,
                                          child: Center(
                                              child: WPLogo(
                                                  edition: edition,
                                                  height: 44,
                                                  width: 100))),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                            Text('${edition.label} Edition',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            Text(
                                                Uri.parse(edition.site)
                                                    .host
                                                    .replaceFirst('www.', ''),
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: AppColors.muted)),
                                          ])),
                                    ]),
                                  )),
                          ],
                        );
                        if (edition == null ||
                            edition == ref.read(editionProvider) ||
                            !context.mounted) {
                          return;
                        }
                        final prefs = await SharedPreferences.getInstance();
                        for (final key in prefs.getKeys().where((key) => key
                            .startsWith('content_cache_v2:${edition.name}:'))) {
                          await prefs.remove(key);
                        }
                        if (!context.mounted) return;
                        final router = GoRouter.of(context);
                        ref.invalidate(editionConfigProvider(edition));
                        ref.read(editionProvider.notifier).state = edition;
                        router.go('/feed');
                      },
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Flexible(child: WPLogo(height: 36)),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: ref
                                  .watch(activeConfigProvider)
                                  .primary
                                  .withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.expand_more,
                              size: 18,
                              color: ref.watch(activeConfigProvider).primary),
                        ),
                      ]),
                    )),
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
            onPressed: () => showNotificationSettings(context),
          ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1),
      ),
    );
  }
}
