import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;
import 'package:url_launcher/url_launcher.dart';

import '../../core/edition/edition.dart';
import '../../widgets/regional_page_content.dart';
import '../../widgets/social_links.dart';
import '../../widgets/wp_scaffold.dart';

class AboutSection {
  const AboutSection(this.title, this.html);
  final String title, html;
}

// Keep the site's content and links; only reorganize its headings into cards.
List<AboutSection> aboutSections(String html, String defaultTitle) {
  final body = parser.parseFragment(html);
  for (final node in body.querySelectorAll('script,style,iframe,form')) {
    node.remove();
  }
  final sections = <AboutSection>[];
  var title = defaultTitle;
  var content = StringBuffer();
  void flush() {
    if (content.isNotEmpty) {
      sections.add(AboutSection(title, content.toString()));
    }
    content = StringBuffer();
  }

  void visit(dom.Node node) {
    if (node is dom.Element) {
      final tag = node.localName;
      final heading = RegExp(r'^h[1-6]$').hasMatch(tag ?? '');
      final boldHeading = tag == 'p' &&
          node.children.length == 1 &&
          ['strong', 'b'].contains(node.children.first.localName) &&
          node.text.trim() == node.children.first.text.trim() &&
          node.text.trim().length < 120;
      if (heading || boldHeading) {
        final text = node.text.trim();
        if (text.isNotEmpty && text.toLowerCase() != 'about us') {
          flush();
          title = text;
        }
      } else if (['div', 'section', 'article', 'main'].contains(tag)) {
        for (final child in node.nodes) {
          visit(child);
        }
      } else if (node.text.trim().isNotEmpty ||
          node.querySelector('img') != null ||
          tag == 'img') {
        content.write(node.outerHtml);
      }
    } else if (node.text?.trim().isNotEmpty ?? false) {
      content.write((dom.Element.tag('p')..text = node.text!).outerHtml);
    }
  }

  for (final node in body.nodes) {
    visit(node);
  }
  flush();
  return sections;
}

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(activeConfigProvider);
    return WPScaffold(
      showBack: true,
      child: ColoredBox(
        color: const Color(0xFFFAF8F5),
        child: ListView(children: [
          const _AboutHero(),
          if (config.aboutPageId > 0)
            ref.watch(regionalPageProvider(config.aboutPageId)).when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator())),
                error: (_, __) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      const Text('About Us could not load.'),
                      TextButton(
                          onPressed: () => ref.invalidate(
                              regionalPageProvider(config.aboutPageId)),
                          child: const Text('Retry')),
                    ])),
                data: (html) {
                  final sections = aboutSections(
                      html, 'Wood & Panel ${config.edition.label}');
                  if (sections.isEmpty) {
                    return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('About Us content is not available yet.'));
                  }
                  return Column(children: [
                    for (var i = 0; i < sections.length; i++)
                      _AboutCard(section: sections[i], index: i),
                  ]);
                })
          else
            const Padding(
                padding: EdgeInsets.all(24),
                child: Text('About Us content is not available yet.')),
          const Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 20),
              child: _StayConnected()),
        ]),
      ),
    );
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
        builder: (context, box) => Stack(children: [
              Positioned.fill(
                  child: Align(
                      alignment: Alignment.centerRight,
                      child: FractionallySizedBox(
                          widthFactor: .46,
                          heightFactor: 1,
                          child: Image.asset('assets/home_banners/banner_4.png',
                              fit: BoxFit.cover,
                              alignment: Alignment.centerRight)))),
              Positioned.fill(
                  child: CustomPaint(
                      painter: _HeroShape(colors.primary, colors.secondary))),
              Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, box.maxWidth * .36, 24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 26, height: 3, color: colors.primary),
                        const SizedBox(height: 6),
                        Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                  text: 'About ',
                                  style: TextStyle(color: colors.secondary)),
                              TextSpan(
                                  text: 'Us',
                                  style: TextStyle(color: colors.primary)),
                            ]),
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(fontSize: 32)),
                        const SizedBox(height: 6),
                        const Text(
                            'Your gateway to the latest news, insights and updates from the global wood and panel industry.',
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Color(0xFF575D70))),
                      ])),
            ]));
  }
}

class _HeroShape extends CustomPainter {
  _HeroShape(this.primary, this.secondary);
  final Color primary, secondary;
  @override
  void paint(Canvas canvas, Size size) {
    for (final layer in [
      (0.0, secondary),
      (-8.0, primary),
      (-16.0, const Color(0xFFFAF7F1))
    ]) {
      final path = Path()
        ..lineTo(size.width * .56 + layer.$1, 0)
        ..lineTo(size.width * .72 + layer.$1, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = layer.$2);
    }
  }

  @override
  bool shouldRepaint(_HeroShape old) =>
      old.primary != primary || old.secondary != secondary;
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.section, required this.index});
  final AboutSection section;
  final int index;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = index == 0
        ? Icons.description_outlined
        : section.title.toLowerCase().contains('feature')
            ? Icons.settings_outlined
            : Icons.public;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .025),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(alpha: .08)),
            child: Icon(icon, color: colors.primary, size: 24)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(section.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 20,
                  color: colors.secondary,
                  fontWeight: FontWeight.w700)),
          Container(
              margin: const EdgeInsets.symmetric(vertical: 7),
              width: 26,
              height: 3,
              color: colors.primary),
          HtmlWidget(section.html,
              textStyle: const TextStyle(
                  fontSize: 13, height: 1.45, color: Color(0xFF575D70)),
              customStylesBuilder: (element) => switch (element.localName) {
                    'p' => {'margin': '0 0 8px 0'},
                    'ul' => {
                        'padding-left': '0',
                        'list-style-type': 'none',
                        'margin': '0'
                      },
                    'li' => {'margin-bottom': '6px'},
                    _ => null,
                  },
              customWidgetBuilder: (element) {
                if (element.localName != 'li' ||
                    element.parent?.localName != 'ul') {
                  return null;
                }
                return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(Icons.check_circle,
                                  size: 15, color: colors.primary)),
                          const SizedBox(width: 7),
                          Expanded(
                              child: HtmlWidget(element.innerHtml,
                                  textStyle: const TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: Color(0xFF575D70)),
                                  onTapUrl: _openLink)),
                        ]));
              },
              onTapUrl: _openLink),
        ])),
      ]),
    );
  }
}

Future<bool> _openLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !['https', 'http', 'mailto', 'tel'].contains(uri.scheme)) {
    return false;
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

class _StayConnected extends StatelessWidget {
  const _StayConnected();
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Stack(children: [
        Positioned.fill(
            child: Image.asset('assets/home_banners/banner_4.png',
                alignment: Alignment.centerRight, fit: BoxFit.cover)),
        Positioned.fill(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
          Theme.of(context).colorScheme.secondary,
          Theme.of(context).colorScheme.secondary,
          Colors.transparent
        ], stops: const [
          0,
          .58,
          .82
        ])))),
        Padding(
            padding: const EdgeInsets.all(12),
            child: FractionallySizedBox(
                widthFactor: .68,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stay Connected',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontSize: 19, color: Colors.white)),
                      const SizedBox(height: 3),
                      const Text(
                          'Follow us for the latest news, updates and insights from the wood and panel industry.',
                          style: TextStyle(
                              fontSize: 10, height: 1.35, color: Colors.white)),
                      const SizedBox(height: 7),
                      const SocialLinks(compact: true, iconsOnly: true),
                    ]))),
      ]));
}
