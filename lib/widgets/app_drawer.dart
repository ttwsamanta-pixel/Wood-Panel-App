import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/edition/edition.dart';
import '../data/repositories/user_profile_repository.dart';
import '../features/profile/profile_actions.dart';
import 'social_links.dart';
import 'wp_logo.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});
  static const items = [
    ('Home', Icons.home_outlined, '/home', Colors.red),
    ('Explore', Icons.explore_outlined, '/explore', Colors.blue),
    ('Feed', Icons.newspaper_outlined, '/feed', Colors.green),
    ('Magazine', Icons.menu_book_outlined, '/magazine', Colors.brown),
    ('Videos', Icons.play_circle_outline, '/videos', Colors.purple),
    ('Bookmarks', Icons.bookmark_outline, '/bookmarks', Colors.pink),
    ('Downloads', Icons.download_outlined, '/downloads', Colors.blue),
    ('Wallpapers', Icons.wallpaper, '/wallpapers', Colors.green),
    ('Events', Icons.event_outlined, '/events', Colors.deepOrange),
    ('Grow With Us', Icons.handshake_outlined, '/grow-with-us', Colors.red),
    ('Contact Us', Icons.mail_outline, '/contact', Colors.blue),
    ('About Us', Icons.info_outline, '/about', Colors.blueGrey),
    ('Rate Our App', Icons.star_rounded, 'rate', Colors.amber),
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile =
        ref.watch(userProfileProvider).valueOrNull ?? const UserProfile();
    final edition = ref.watch(editionProvider);
    final colors = Theme.of(context).colorScheme;
    final path = GoRouterState.of(context).uri.path;
    void open(String route) {
      final host = Navigator.of(context, rootNavigator: true).context;
      Navigator.of(context).pop();
      openProfileAction(host, ref, route);
    }

    return Drawer(
        width: MediaQuery.sizeOf(context).width * .88,
        backgroundColor: Colors.white,
        child: SafeArea(child: LayoutBuilder(builder: (context, box) {
          // Reserve the header and footer first, then distribute all menu rows.
          final rowHeight =
              ((box.maxHeight - 232) / items.length).clamp(30.0, 48.0);
          return SingleChildScrollView(
              child: Column(children: [
            SizedBox(
                height: 96,
                child: Stack(children: [
                  Positioned.fill(
                      child: Image.asset('assets/home_banners/banner_4.png',
                          fit: BoxFit.cover, alignment: Alignment.centerRight)),
                  Positioned.fill(
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                    Colors.white,
                    Colors.white.withValues(alpha: .96),
                    Colors.white.withValues(alpha: 0)
                  ], stops: const [
                    0,
                    .55,
                    1
                  ])))),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 5, 10, 6),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const WPLogo(width: 126, height: 26),
                              const Spacer(),
                              IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      minimumSize: const Size(30, 30),
                                      padding: const EdgeInsets.all(4),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap),
                                  icon: const Icon(Icons.close, size: 20))
                            ]),
                            const SizedBox(height: 2),
                            Text(
                                profile.name.isEmpty
                                    ? 'Welcome!'
                                    : 'Welcome, ${profile.displayName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    height: 1.05)),
                            const SizedBox(height: 3),
                            SizedBox(
                                width: 220,
                                child: Text(
                                    'Explore the latest news, insights and updates from Wood & Panel ${edition.label}',
                                    maxLines: 2,
                                    style: const TextStyle(
                                        fontSize: 10.5, height: 1.2))),
                          ])),
                ])),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [
                  for (final item in items)
                    SizedBox(
                        height: rowHeight,
                        child: Material(
                            color: path == item.$3
                                ? colors.primary.withValues(alpha: .09)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => open(item.$3),
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5),
                                    child: Row(children: [
                                      Container(
                                          width: rowHeight - 6,
                                          height: rowHeight - 6,
                                          decoration: BoxDecoration(
                                              color: path == item.$3
                                                  ? colors.primary
                                                  : item.$4
                                                      .withValues(alpha: .10),
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          child: Icon(item.$2,
                                              size: 22,
                                              color: path == item.$3
                                                  ? Colors.white
                                                  : item.$4)),
                                      const SizedBox(width: 14),
                                      Expanded(
                                          child: Container(
                                              alignment: Alignment.centerLeft,
                                              decoration: const BoxDecoration(
                                                  border: Border(
                                                      bottom: BorderSide(
                                                          color: Color(
                                                              0xFFF2F2F2)))),
                                              child: Row(children: [
                                                Expanded(
                                                    child: Text(item.$1,
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: path ==
                                                                    item.$3
                                                                ? colors.primary
                                                                : const Color(
                                                                    0xFF101B30)))),
                                                const Icon(Icons.chevron_right,
                                                    size: 17)
                                              ]))),
                                    ]))))),
                  const SizedBox(height: 6),
                  SizedBox(
                      height: 64,
                      child: Material(
                          color: colors.secondary,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => open('newsletter'),
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  child: Row(children: [
                                    const Expanded(
                                        child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text('Subscribe to our',
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          height: 1.15)),
                                                  Text('Newsletter',
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          height: 1.15)),
                                                  Text(
                                                      'Latest news and industry updates.',
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 9,
                                                          height: 1.2)),
                                                ]))),
                                    Icon(Icons.mark_email_unread_rounded,
                                        color: Colors.lightBlue.shade100,
                                        size: 32),
                                    const SizedBox(width: 8),
                                    CircleAvatar(
                                        radius: 14,
                                        backgroundColor: colors.primary,
                                        child: const Icon(Icons.arrow_forward,
                                            color: Colors.white, size: 17)),
                                  ]))))),
                  const SizedBox(height: 6),
                  const SizedBox(
                      height: 40,
                      child: Row(children: [
                        Text('Follow Us',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Expanded(
                            child: SocialLinks(compact: true, iconsOnly: true))
                      ])),
                  const SizedBox(
                      height: 14,
                      child: Text('App Version 0.1.0',
                          style: TextStyle(fontSize: 8, color: Colors.grey))),
                  const SizedBox(height: 6),
                ])),
          ]));
        })));
  }
}
