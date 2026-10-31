import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/edition/edition.dart';
import '../../data/repositories/bookmark_repository.dart';
import '../../data/repositories/content_providers.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../widgets/social_links.dart';
import '../../widgets/wp_scaffold.dart';
import 'profile_editor.dart';
import 'profile_actions.dart';

final profileStatsProvider = FutureProvider.autoDispose<List<int>>((ref) async {
  final edition = ref.watch(editionProvider).name;
  final bookmarks = ref.watch(bookmarkRepositoryProvider);
  final downloads = ref.watch(downloadRepositoryProvider);
  final ids = await bookmarks.articleIds();
  final files =
      (await downloads.files()).where((f) => f.edition == edition).toList();
  final prefs = await SharedPreferences.getInstance();
  return [
    ids.length,
    files.length,
    files.where((f) => f.path.toLowerCase().endsWith('.pdf')).length,
    (prefs.getStringList('articles_read_v1:$edition') ?? []).length
  ];
});

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  static const items = [
    (
      'Bookmarks',
      'View and manage your saved articles',
      Icons.bookmark_border,
      '/bookmarks'
    ),
    (
      'Downloads',
      'Access your downloaded content',
      Icons.download_outlined,
      '/downloads'
    ),
    (
      'My Magazine',
      'Read and manage your magazine issues',
      Icons.menu_book_outlined,
      '/magazine'
    ),
    (
      'Notifications',
      'Manage your notification settings',
      Icons.notifications_none,
      'notifications'
    ),
    (
      'Preferences',
      'App settings and display options',
      Icons.settings_outlined,
      '/preferences'
    ),
    (
      'Newsletter',
      'Get the latest news and industry updates',
      Icons.mail_outline,
      'newsletter'
    ),
    (
      'Videos',
      'Watch latest videos and interviews',
      Icons.play_circle_outline,
      '/videos'
    ),
    (
      'Events',
      'View upcoming events and exhibitions',
      Icons.event_outlined,
      '/events'
    ),
    (
      'Wallpapers',
      'Browse and save your favourite wallpapers',
      Icons.wallpaper,
      '/wallpapers'
    ),
    (
      'Rate Our App',
      'Share your experience on the app store',
      Icons.star_border,
      'rate'
    ),
    (
      'Share App',
      'Share Wood & Panel with your friends',
      Icons.share_outlined,
      'share'
    ),
    ('About Us', 'Learn more about Wood & Panel', Icons.info_outline, '/about'),
    (
      'Contact Us',
      'Get in touch with our team',
      Icons.mail_outline,
      '/contact'
    ),
    (
      'Grow With Us',
      'Partner with Wood & Panel',
      Icons.handshake_outlined,
      '/grow-with-us'
    ),
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile =
        ref.watch(userProfileProvider).valueOrNull ?? const UserProfile();
    final colors = Theme.of(context).colorScheme;
    final stats = ref.watch(profileStatsProvider).valueOrNull;
    return WPScaffold(
        child: ColoredBox(
            color: Theme.of(context).brightness == Brightness.dark
                ? colors.surfaceContainerLowest
                : const Color(0xFFFAF9F7),
            child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
                children: [
                  LayoutBuilder(builder: (context, box) {
                    final heroHeight = box.maxWidth * .38 +
                        40 +
                        (profile.email.isNotEmpty ? 16 : 0);
                    return SizedBox(
                        height: heroHeight + 42,
                        child: Stack(children: [
                          Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: heroHeight,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(children: [
                                    Positioned.fill(
                                        child: Image.asset(
                                            'assets/home_banners/banner_4.png',
                                            fit: BoxFit.cover,
                                            alignment: Alignment.centerRight)),
                                    Positioned.fill(
                                        child: ClipPath(
                                            clipper: _ProfileCurve(),
                                            child: ColoredBox(
                                                color: colors.secondary))),
                                  ]))),
                          Positioned(
                              top: 14,
                              right: 10,
                              child: SizedBox(
                                  height: 28,
                                  child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor:
                                              const Color(0xFF141A25),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 9),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8))),
                                      onPressed: () =>
                                          context.push('/edit-profile'),
                                      icon: Icon(Icons.edit,
                                          color: colors.primary, size: 13),
                                      label: const Text('Edit Profile',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700))))),
                          Positioned(
                              top: 17,
                              left: 16,
                              width: box.maxWidth * .48,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      const Icon(Icons.wb_sunny_outlined,
                                          color: Color(0xFFFFD629), size: 20),
                                      const SizedBox(width: 5),
                                      Expanded(
                                          child: Text(profileGreeting(),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11)))
                                    ]),
                                    const SizedBox(height: 5),
                                    Text(profile.displayName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 25,
                                            height: 1.05)),
                                    if (profile.email.isNotEmpty)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(profile.email,
                                              maxLines: 2,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10))),
                                    const SizedBox(height: 10),
                                    const Text(
                                        'Manage your profile, preferences and saved content.',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            height: 1.35)),
                                  ])),
                          Positioned(
                              top: 50,
                              left: box.maxWidth * .56,
                              child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                      color:
                                          Theme.of(context).colorScheme.surface,
                                      shape: BoxShape.circle),
                                  child: ProfileAvatar(
                                      profile: profile,
                                      radius: box.maxWidth * .095))),
                          Positioned(
                              left: 9,
                              right: 9,
                              bottom: 0,
                              height: 82,
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 4),
                                  decoration: BoxDecoration(
                                      color:
                                          Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(13),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Color(0x10000000),
                                            blurRadius: 18,
                                            offset: Offset(0, 6))
                                      ]),
                                  child: Row(children: [
                                    for (var i = 0; i < 4; i++) ...[
                                      if (i > 0)
                                        const VerticalDivider(
                                            width: 1,
                                            indent: 3,
                                            endIndent: 3,
                                            color: Color(0xFFE4E0DA)),
                                      Expanded(
                                          child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                            Icon(
                                                [
                                                  Icons.bookmark_border,
                                                  Icons.download_outlined,
                                                  Icons.menu_book_outlined,
                                                  Icons.visibility_outlined
                                                ][i],
                                                size: 18,
                                                color: i == 1
                                                    ? colors.secondary
                                                    : colors.primary),
                                            const SizedBox(height: 3),
                                            Text(
                                                stats == null
                                                    ? '-'
                                                    : '${stats[i]}',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                            Text(
                                                [
                                                  'Bookmarks',
                                                  'Downloads',
                                                  'Magazines',
                                                  'Articles Read'
                                                ][i],
                                                style: const TextStyle(
                                                    fontSize: 8,
                                                    color: Color(0xFF5D6273)))
                                          ])),
                                    ],
                                  ]))),
                        ]));
                  }),
                  const SizedBox(height: 12),
                  for (var row = 0; row < items.length; row += 2)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: IntrinsicHeight(
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              for (var i = row; i < row + 2; i++) ...[
                                if (i > row) const SizedBox(width: 8),
                                Expanded(
                                    child: Container(
                                        decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surface,
                                            borderRadius:
                                                BorderRadius.circular(13),
                                            boxShadow: const [
                                              BoxShadow(
                                                  color: Color(0x07000000),
                                                  blurRadius: 12,
                                                  offset: Offset(0, 3))
                                            ]),
                                        child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(13),
                                                onTap: () => openProfileAction(
                                                    context, ref, items[i].$4),
                                                child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 9,
                                                        vertical: 12),
                                                    child: Row(children: [
                                                      Container(
                                                          width: 32,
                                                          height: 36,
                                                          decoration: BoxDecoration(
                                                              color: ([
                                                                1,
                                                                3,
                                                                5,
                                                                8,
                                                                12
                                                              ].contains(i)
                                                                      ? colors
                                                                          .secondary
                                                                      : colors
                                                                          .primary)
                                                                  .withValues(
                                                                      alpha:
                                                                          .08),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10)),
                                                          child: Icon(
                                                              items[i].$3,
                                                              size: 23,
                                                              color: [
                                                                1,
                                                                3,
                                                                5,
                                                                8,
                                                                12
                                                              ].contains(i)
                                                                  ? colors
                                                                      .secondary
                                                                  : colors
                                                                      .primary)),
                                                      const SizedBox(width: 7),
                                                      Expanded(
                                                          child: Column(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                            Text(items[i].$1,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800)),
                                                            const SizedBox(
                                                                height: 4),
                                                            Text(items[i].$2,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        9.5,
                                                                    height: 1.2,
                                                                    color: Color(
                                                                        0xFF626775)))
                                                          ])),
                                                      const Icon(
                                                          Icons.chevron_right,
                                                          size: 12,
                                                          color: Color(
                                                              0xFF131C2D)),
                                                    ])))))),
                              ],
                            ]))),
                  Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: colors.secondary.withValues(alpha: .045)),
                      child: Row(children: [
                        Expanded(
                            flex: 4,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Follow Us',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: colors.secondary)),
                                  Container(
                                      width: 25,
                                      height: 2,
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 5),
                                      color: colors.primary),
                                  const Text(
                                      'Stay connected for the latest news, updates and insights.',
                                      style:
                                          TextStyle(fontSize: 9, height: 1.3))
                                ])),
                        const SizedBox(width: 8),
                        Container(
                            width: 1,
                            height: 55,
                            color: const Color(0xFFD9D3CA)),
                        const SizedBox(width: 8),
                        const Expanded(
                            flex: 7,
                            child: SocialLinks(compact: true, iconsOnly: true)),
                      ])),
                ])));
  }
}

class _ProfileCurve extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(size.width * .39, 0)
    ..cubicTo(size.width * .65, size.height * .26, size.width * .68,
        size.height * .64, size.width * .43, size.height)
    ..lineTo(0, size.height)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
