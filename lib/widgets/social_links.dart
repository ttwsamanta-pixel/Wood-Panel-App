import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/edition/edition.dart';

class SocialLinks extends ConsumerWidget {
  const SocialLinks({super.key, this.compact = false, this.iconsOnly = false});
  final bool compact;
  final bool iconsOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(activeConfigProvider).socialLinks;
    final items = [
      (
        'facebook',
        'Facebook',
        FontAwesomeIcons.facebookF,
        const Color(0xFF1877F2)
      ),
      ('x', 'X', FontAwesomeIcons.xTwitter, Colors.black),
      (
        'instagram',
        'Instagram',
        FontAwesomeIcons.instagram,
        const Color(0xFFC13584)
      ),
      (
        'linkedin',
        'LinkedIn',
        FontAwesomeIcons.linkedinIn,
        const Color(0xFF0077B5)
      ),
      ('youtube', 'YouTube', FontAwesomeIcons.youtube, const Color(0xFFFF0000)),
      (
        'whatsapp',
        'WhatsApp',
        FontAwesomeIcons.whatsapp,
        const Color(0xFF25D366)
      ),
    ];
    return Container(
      padding: EdgeInsets.all(iconsOnly
          ? 0
          : compact
              ? 8
              : 14),
      decoration: BoxDecoration(
          color: iconsOnly
              ? Colors.transparent
              : Theme.of(context).colorScheme.secondary.withValues(alpha: .045),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!iconsOnly)
          Text('Follow Us',
              style: TextStyle(
                  fontSize: compact ? 12 : 20,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.secondary)),
        if (!compact && !iconsOnly)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                  'Stay connected for the latest news, updates and insights.',
                  style: TextStyle(fontSize: 12))),
        if (!iconsOnly) const SizedBox(height: 8),
        Row(children: [
          for (final item in items)
            if ((links[item.$1] ?? '').isNotEmpty)
              Expanded(
                  child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () async {
                        final uri = Uri.tryParse(links[item.$1]!);
                        if (uri?.scheme != 'https') return;
                        try {
                          await launchUrl(uri!,
                              mode: LaunchMode.externalApplication);
                        } catch (_) {}
                      },
                      child: Padding(
                          padding: const EdgeInsets.all(3),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                                width: iconsOnly
                                    ? 25
                                    : compact
                                        ? 32
                                        : 38,
                                height: iconsOnly
                                    ? 25
                                    : compact
                                        ? 32
                                        : 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: item.$4,
                                    gradient: item.$1 == 'instagram'
                                        ? const LinearGradient(
                                            colors: [
                                                Color(0xFF833AB4),
                                                Color(0xFFE1306C),
                                                Color(0xFFFCAF45)
                                              ],
                                            begin: Alignment.topRight,
                                            end: Alignment.bottomLeft)
                                        : null),
                                child: FaIcon(item.$3,
                                    size: iconsOnly
                                        ? 14
                                        : compact
                                            ? 17
                                            : 21,
                                    color: Colors.white)),
                            if (!compact && !iconsOnly)
                              Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(item.$2,
                                          style:
                                              const TextStyle(fontSize: 9)))),
                          ])))),
        ]),
      ]),
    );
  }
}
