import 'package:flutter/material.dart';

class SettingsHero extends StatelessWidget {
  const SettingsHero({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 108),
      margin: const EdgeInsets.only(bottom: 4),
      child: Stack(children: [
        Positioned.fill(
            child:
                Image.asset('assets/wallpapers/grain.png', fit: BoxFit.cover)),
        Positioned.fill(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
          c.surface,
          c.surface.withValues(alpha: .96),
          c.surface.withValues(alpha: .12)
        ], stops: const [
          0,
          .57,
          1
        ])))),
        Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 70, 24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: c.onSurface)),
              const SizedBox(height: 5),
              Text(subtitle,
                  style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
            ])),
      ]),
    );
  }
}

BoxDecoration settingsDecoration(BuildContext context) {
  final c = Theme.of(context).colorScheme;
  return BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: c.outlineVariant.withValues(alpha: .22)),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 14,
            offset: const Offset(0, 4))
      ]);
}

class SettingsCard extends StatelessWidget {
  const SettingsCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.description,
      required this.child});
  final IconData icon;
  final String title, description;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.all(12),
        decoration: settingsDecoration(context),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 36,
              height: 40,
              decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: c.primary, size: 23)),
          const SizedBox(width: 10),
          Expanded(
              child: Material(
                  color: Colors.transparent,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(title,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700))),
                          if (title == 'Appearance') const _PhonePreview(),
                          if (title == 'Text Size')
                            Text('Aa',
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    color: c.primary)),
                        ]),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(description,
                              style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: c.onSurfaceVariant))
                        ],
                        const SizedBox(height: 10),
                        child,
                      ]))),
        ]));
  }
}

class LegalSection {
  const LegalSection(this.title, this.body);
  final String title, body;
}

// Preserve every editor-supplied paragraph. A short first line followed by
// a newline is treated as a section heading; ordinary paragraphs stay intact.
List<LegalSection> legalSections(String content, String pageTitle) {
  final blocks =
      content.replaceAll('\r\n', '\n').trim().split(RegExp(r'\n\s*\n'));
  if (blocks.isNotEmpty &&
      blocks.first.trim().toLowerCase() == pageTitle.toLowerCase()) {
    blocks.removeAt(0);
  }
  if (blocks.isEmpty) return [LegalSection(pageTitle, content)];
  final result = <LegalSection>[LegalSection(pageTitle, blocks.removeAt(0))];
  for (final block in blocks) {
    final split = block.indexOf('\n');
    if (split > 0 && split < 100) {
      result.add(LegalSection(
          block.substring(0, split).trim(), block.substring(split + 1).trim()));
    } else {
      result.add(LegalSection('More information', block));
    }
  }
  return result;
}

class LegalSectionCard extends StatefulWidget {
  const LegalSectionCard(
      {super.key,
      required this.section,
      required this.index,
      required this.privacy});
  final LegalSection section;
  final int index;
  final bool privacy;
  @override
  State<LegalSectionCard> createState() => _LegalSectionCardState();
}

class _LegalSectionCardState extends State<LegalSectionCard> {
  bool expanded = true;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final icons = widget.privacy
        ? [
            Icons.person,
            Icons.storage_rounded,
            Icons.notifications,
            Icons.verified_user,
            Icons.mail,
            Icons.update
          ]
        : [
            Icons.newspaper,
            Icons.copyright,
            Icons.link,
            Icons.person,
            Icons.sync,
            Icons.mail
          ];
    return Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 7),
        decoration: settingsDecoration(context),
        child: Material(
            color: Colors.transparent,
            child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => expanded = !expanded),
                child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                              radius: 9,
                              backgroundColor: c.primary.withValues(alpha: .10),
                              child: Text('${widget.index}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: c.primary,
                                      fontWeight: FontWeight.bold))),
                          const SizedBox(width: 7),
                          CircleAvatar(
                              radius: 18,
                              backgroundColor: c.primary.withValues(alpha: .10),
                              child: Icon(
                                  icons[(widget.index - 1) % icons.length],
                                  size: 21,
                                  color: c.primary)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(widget.section.title,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                if (expanded) ...[
                                  const SizedBox(height: 3),
                                  Text(widget.section.body,
                                      style: TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: c.onSurfaceVariant))
                                ],
                              ])),
                          Icon(
                              expanded
                                  ? Icons.keyboard_arrow_down
                                  : Icons.chevron_right,
                              size: 18,
                              color: c.onSurfaceVariant),
                        ])))));
  }
}

class _PhonePreview extends StatelessWidget {
  const _PhonePreview();
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 50,
      height: 40,
      child: Row(children: [
        for (final dark in [false, true])
          Container(
              width: 23,
              margin: const EdgeInsets.only(left: 2),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  color:
                      dark ? const Color(0xFF161616) : const Color(0xFFFFF4E8),
                  borderRadius: BorderRadius.circular(5),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.primary)),
              child: Column(children: [
                Icon(dark ? Icons.nightlight_round : Icons.wb_sunny_outlined,
                    size: 10,
                    color: dark
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary),
                const SizedBox(height: 3),
                Icon(Icons.image,
                    size: 12,
                    color: dark ? Colors.white38 : Colors.brown.shade200),
                Container(
                    height: 2,
                    color: dark ? Colors.white38 : Colors.brown.shade200),
              ])),
      ]));
}
