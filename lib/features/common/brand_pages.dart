import '../../widgets/social_links.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/wp_scaffold.dart';
import '../../data/repositories/app_api_repository.dart';
import '../../core/edition/edition.dart';

const _paper = Color(0xFFFAF7F2);

class PartnerPage extends StatelessWidget {
  const PartnerPage({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return WPScaffold(
        showBack: true,
        child: ColoredBox(
            color: _paper,
            child: ListView(children: [
              LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(children: [
                  Positioned(
                      top: 24,
                      bottom: 0,
                      right: 0,
                      width: width * .39,
                      child: ClipPath(
                          clipper: _PartnerClip(),
                          child: Image.asset('assets/pages/partner.png',
                              fit: BoxFit.cover, alignment: Alignment.center))),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 18, 20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.handshake_rounded,
                                size: 46, color: colors.primary),
                            const SizedBox(height: 16),
                            Text('G R O W   T O G E T H E R',
                                style: TextStyle(
                                    color: colors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            SizedBox(
                                width: width * .72,
                                child: _Title('Partner with', 'Wood & Panel',
                                    large: true)),
                            const SizedBox(height: 14),
                            SizedBox(
                                width: width * .60,
                                child: const Text(
                                    'Join a global platform that connects brands, professionals and innovators across the wood, panel and interior industry.',
                                    style:
                                        TextStyle(fontSize: 13, height: 1.4))),
                            const SizedBox(height: 20),
                            for (final point in const [
                              (
                                Icons.campaign_rounded,
                                'Advertising opportunities',
                                'Reach a targeted and influential audience worldwide.'
                              ),
                              (
                                Icons.calendar_month_rounded,
                                'Event partnerships',
                                'Collaborate on industry events and exhibitions.'
                              ),
                              (
                                Icons.groups_rounded,
                                'Brand collaborations',
                                'Create impactful campaigns together.'
                              ),
                              (
                                Icons.bar_chart_rounded,
                                'Digital solutions',
                                'Custom solutions to grow your brand online.'
                              ),
                            ])
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 18),
                                  child: SizedBox(
                                      width: width * .62,
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _RoundIcon(point.$1,
                                                color: colors.primary,
                                                size: 36),
                                            const SizedBox(width: 10),
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Text(point.$2,
                                                      style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w800)),
                                                  const SizedBox(height: 3),
                                                  Text(point.$3,
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          height: 1.35,
                                                          color: Color(
                                                              0xFF555555))),
                                                ])),
                                          ]))),
                          ])),
                ]);
              }),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                    decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(16)),
                    child: IntrinsicHeight(
                        child: Row(children: [
                      _Stat(Icons.groups, '50K+', 'Industry\nProfessionals'),
                      VerticalDivider(
                          color: colors.primary.withValues(alpha: .2)),
                      _Stat(Icons.public, '100+', 'Countries\nWorldwide'),
                      VerticalDivider(
                          color: colors.primary.withValues(alpha: .2)),
                      _Stat(
                          Icons.article, 'Daily', 'Industry\nNews & Insights'),
                    ])),
                  )),
              Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                  child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      onPressed: () => context.push('/contact'),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Get In Touch'))),
            ])));
  }
}

class ContactPage extends ConsumerStatefulWidget {
  const ContactPage({super.key});
  @override
  ConsumerState<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends ConsumerState<ContactPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _phone = TextEditingController(),
      _subject = TextEditingController(),
      _message = TextEditingController();
  bool _sending = false, _sent = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _subject, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || !(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(appApiRepositoryProvider).sendContactMessage(
          name: _name.text.trim(),
          email: _email.text.trim(),
          subject: _subject.text.trim(),
          message:
              '${_phone.text.trim().isEmpty ? '' : 'Phone: ${_phone.text.trim()}\n\n'}${_message.text.trim()}');
      if (mounted) {
        setState(() {
          _sending = false;
          _sent = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Your message could not be sent. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(activeConfigProvider).contactDetails;
    String d(String key) => details[key] ?? defaultContactDetails[key]!;
    String phone(String key) =>
        'tel:${d(key).replaceAll(RegExp(r"[^+0-9]"), "")}';
    final colors = Theme.of(context).colorScheme;
    return WPScaffold(
        showBack: true,
        child: ColoredBox(
            color: _paper,
            child:
                ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 164),
                  child: Stack(children: [
                    Positioned(
                        top: 0,
                        right: 0,
                        bottom: 0,
                        width: 140,
                        child: ClipPath(
                            clipper: _ContactClip(),
                            child: Image.asset(
                                'assets/home_banners/banner_4.png',
                                fit: BoxFit.cover,
                                alignment: Alignment.centerRight))),
                    Padding(
                        padding: const EdgeInsets.fromLTRB(18, 22, 110, 12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _Title('Contact', 'Us'),
                              const SizedBox(height: 8),
                              Container(
                                  width: 28, height: 3, color: colors.primary),
                              const SizedBox(height: 8),
                              const Text(
                                  'We’d love to hear from you. Get in touch with our team for any inquiries, partnerships or support.',
                                  style: TextStyle(fontSize: 12, height: 1.35)),
                            ])),
                  ])),
              _InfoCard(
                  icon: Icons.location_on,
                  title: 'USA Address',
                  text: d('usa_address'),
                  contacts: [
                    (d('usa_phone'), phone('usa_phone')),
                    (
                      d('usa_whatsapp'),
                      'https://wa.me/${d('usa_whatsapp').replaceAll(RegExp(r'[^0-9]'), '')}'
                    )
                  ]),
              _InfoCard(
                  icon: Icons.location_on,
                  title: 'India Address',
                  text: d('india_address'),
                  contacts: [
                    (d('india_phone'), phone('india_phone')),
                    (d('india_mobile'), phone('india_mobile'))
                  ]),
              _Surface(
                  child: Row(children: [
                _RoundIcon(Icons.mail, color: colors.secondary, size: 40),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Mail',
                          style: TextStyle(
                              color: colors.secondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      _ContactLink(d('email'), 'mailto:${d('email')}'),
                      _ContactLink(d('email_secondary'),
                          'mailto:${d('email_secondary')}'),
                    ])),
                Icon(Icons.send_rounded,
                    color: colors.primary.withValues(alpha: .18), size: 32),
              ])),
              _Surface(
                  child: _sent
                      ? SizedBox(
                          height: 220,
                          child: Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                Icon(Icons.check_circle_outline,
                                    size: 52, color: colors.primary),
                                const SizedBox(height: 12),
                                const _Title('Thank', 'you!'),
                                const SizedBox(height: 8),
                                const Text('Your message has been sent.',
                                    textAlign: TextAlign.center),
                              ])))
                      : Form(
                          key: _form,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _Title('Send us a', 'Message',
                                    small: true),
                                const SizedBox(height: 12),
                                _field(_name, 'Name *', Icons.person_outline),
                                _field(_email, 'Email *', Icons.mail_outline,
                                    type: TextInputType.emailAddress),
                                _field(_phone, 'Phone Number',
                                    Icons.phone_outlined,
                                    required: false, type: TextInputType.phone),
                                _field(_subject, 'Subject *', Icons.subject),
                                _field(
                                    _message, 'Message *', Icons.chat_outlined,
                                    lines: 4),
                                if (_error != null)
                                  Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(_error!,
                                          style:
                                              TextStyle(color: colors.error))),
                                SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                        onPressed: _sending ||
                                                !ref
                                                    .watch(activeConfigProvider)
                                                    .contact
                                            ? null
                                            : _submit,
                                        style: FilledButton.styleFrom(
                                            minimumSize:
                                                const Size.fromHeight(48),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8))),
                                        icon: const Icon(Icons.send_rounded),
                                        label: Text(_sending
                                            ? 'Sending…'
                                            : 'Send Message'))),
                              ]))),
              const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SocialLinks()),
              Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14)),
                  child: Column(children: [
                    Container(
                        color: colors.secondary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(children: [
                          const Expanded(
                              child: Text('Our Team',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800))),
                          Icon(Icons.groups,
                              color: Colors.white.withValues(alpha: .35),
                              size: 30)
                        ])),
                    Container(
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: _paper,
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                      border: Border.all(color: colors.primary),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.asset(
                                          'assets/pages/team.jpg',
                                          width: 76,
                                          height: 104,
                                          fit: BoxFit.cover))),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(d('team_name'),
                                        style: TextStyle(
                                            color: colors.secondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 5),
                                    Text(d('team_role'),
                                        style: TextStyle(fontSize: 11)),
                                    const SizedBox(height: 5),
                                    _ContactLink(d('team_email'),
                                        'mailto:${d('team_email')}'),
                                    _ContactLink(
                                        d('team_phone'), phone('team_phone')),
                                  ])),
                            ])),
                  ])),
            ])));
  }

  Widget _field(TextEditingController c, String hint, IconData icon,
          {bool required = true, TextInputType? type, int lines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            controller: c,
            keyboardType: type,
            maxLines: lines,
            maxLength: lines > 1 ? 500 : (c == _subject ? 200 : null),
            validator: (value) {
              final text = (value ?? '').trim();
              if (required && text.isEmpty) {
                return 'Please enter ${hint.replaceAll(' *', '').toLowerCase()}';
              }
              if (c == _email &&
                  !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
                return 'Enter a valid email address';
              }
              return null;
            },
            decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: const Color(0xFFFAF9F7),
                prefixIcon:
                    Icon(icon, color: Theme.of(context).colorScheme.primary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE6E0DA))),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
          ));
}

class _Title extends StatelessWidget {
  const _Title(this.first, this.last, {this.large = false, this.small = false});
  final String first, last;
  final bool large, small;
  @override
  Widget build(BuildContext context) => Text.rich(
      TextSpan(children: [
        TextSpan(text: '$first${large ? '\n' : ' '}'),
        TextSpan(
            text: last,
            style: TextStyle(color: Theme.of(context).colorScheme.primary))
      ]),
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontSize: large
              ? 34
              : small
                  ? 25
                  : 32,
          fontWeight: FontWeight.w800,
          height: 1.08,
          color: Theme.of(context).colorScheme.secondary));
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon(this.icon, {required this.color, required this.size});
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle, color: color.withValues(alpha: .10)),
      child: Icon(icon, color: color, size: size * .55));
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.value, this.label);
  final IconData icon;
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
          child: Column(children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        const SizedBox(height: 5),
        Text(value,
            style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary)),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, height: 1.4))
      ]));
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))
          ]),
      child: child);
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(
      {required this.icon,
      required this.title,
      required this.text,
      required this.contacts});
  final IconData icon;
  final String title, text;
  final List<(String, String)> contacts;
  @override
  Widget build(BuildContext context) => _Surface(
          child: IntrinsicHeight(
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        _RoundIcon(icon,
            color: Theme.of(context).colorScheme.secondary, size: 30),
        const SizedBox(width: 8),
        Expanded(
            flex: 6,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(text, style: const TextStyle(fontSize: 11, height: 1.4)),
                ])),
        const VerticalDivider(width: 16),
        Expanded(
            flex: 5,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final c in contacts)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: InkWell(
                            onTap: () => launchUrl(Uri.parse(c.$2),
                                mode: LaunchMode.externalApplication),
                            child: Row(children: [
                              if (c.$2.contains('wa.me'))
                                FaIcon(FontAwesomeIcons.whatsapp,
                                    size: 15,
                                    color:
                                        Theme.of(context).colorScheme.primary)
                              else
                                Icon(Icons.phone_outlined,
                                    size: 15,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 4),
                              Expanded(
                                  child: Text(c.$1,
                                      style: const TextStyle(fontSize: 10))),
                            ]))),
                ])),
      ])));
}

class _ContactLink extends StatelessWidget {
  const _ContactLink(this.label, this.url);
  final String label, url;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(
                url.startsWith('mailto:')
                    ? Icons.mail_outline
                    : Icons.phone_outlined,
                size: 15,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12)))
          ])));
}

class _PartnerClip extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width * .66, 0)
    ..quadraticBezierTo(s.width * .35, 0, s.width * .28, s.height * .18)
    ..lineTo(0, s.height * .63)
    ..quadraticBezierTo(-5, s.height * .76, s.width * .38, s.height * .8)
    ..lineTo(s.width * .15, s.height * .91)
    ..quadraticBezierTo(0, s.height, s.width, s.height)
    ..lineTo(s.width, 0)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ContactClip extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height)
    ..lineTo(s.width * .6, s.height)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
