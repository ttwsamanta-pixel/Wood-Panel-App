import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/edition/edition.dart';
import '../../core/edition/edition_navigation.dart';
import '../../data/repositories/app_preferences_repository.dart';
import '../../data/repositories/reading_preferences.dart';
import '../../widgets/wp_scaffold.dart';
import 'settings_design.dart';

final appVersionProvider =
    FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());

class PreferencesPage extends ConsumerStatefulWidget {
  const PreferencesPage({super.key});
  @override
  ConsumerState<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends ConsumerState<PreferencesPage> {
  final _tts = FlutterTts();
  bool _busy = false;
  bool _previewing = false;
  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _voices() async {
    try {
      final raw = await _tts.getVoices;
      final voices = <Map<String, String>>[];
      final seen = <String>{};
      if (raw is List) {
        for (final v in raw) {
          if (v is! Map || v['name'] is! String || v['locale'] is! String) {
            continue;
          }
          if (v['isInstalled'] == false || v['isInstalled'] == 'false') {
            continue;
          }
          final key = '${v['locale']}:${v['name']}';
          if (seen.add(key)) {
            voices.add({'name': v['name'], 'locale': v['locale']});
          }
        }
      }
      voices.sort((a, b) => '${a['locale']} ${a['name']}'
          .compareTo('${b['locale']} ${b['name']}'));
      if (!mounted) return;
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
              child: SizedBox(
                  height: MediaQuery.sizeOf(sheetContext).height * .65,
                  child: Column(children: [
                    const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Choose a device voice',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 20))),
                    Expanded(
                        child: ListView(children: [
                      ListTile(
                          title: const Text('Default English voice'),
                          leading: const Icon(Icons.record_voice_over_outlined),
                          onTap: () {
                            ref
                                .read(readingPreferencesProvider.notifier)
                                .setVoice(null);
                            Navigator.pop(sheetContext);
                          }),
                      if (voices.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                                'No additional voices found. Install voices in your phone\'s text-to-speech settings.')),
                      for (final voice in voices)
                        ListTile(
                            title: Text(voice['name']!),
                            subtitle: Text(voice['locale']!),
                            onTap: () {
                              ref
                                  .read(readingPreferencesProvider.notifier)
                                  .setVoice(voice);
                              Navigator.pop(sheetContext);
                            }),
                    ])),
                  ]))));
    } catch (_) {
      _message(
          'Device voices are unavailable. Check your phone\'s text-to-speech settings.');
    }
  }

  Future<void> _preview() async {
    if (_previewing) {
      await _tts.stop();
      if (mounted) setState(() => _previewing = false);
      return;
    }
    try {
      await ref.read(readingPreferencesProvider.notifier).ready;
      await applyReadingVoice(_tts, ref.read(readingPreferencesProvider));
      await _tts.setVolume(1);
      await _tts.setPitch(1);
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _previewing = false);
      });
      _tts.setErrorHandler((_) {
        if (mounted) setState(() => _previewing = false);
      });
      if (!mounted) return;
      setState(() => _previewing = true);
      await _tts.speak(
          'Welcome to Wood and Panel. Listen to the latest news at your preferred pace.');
    } catch (_) {
      if (mounted) setState(() => _previewing = false);
      _message('Audio preview is unavailable on this device.');
    }
  }

  Widget _section(
      IconData icon, String title, String description, List<Widget> children) {
    return SettingsCard(
        icon: icon,
        title: title,
        description: description,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children));
  }

  void _legal(bool privacy) {
    _tts.stop();
    context.push(privacy ? '/privacy-policy' : '/terms-conditions');
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeControllerProvider);
    final reading = ref.watch(readingPreferencesProvider);
    final push = ref.watch(editionPushProvider);
    final colors = Theme.of(context).colorScheme;
    final version = ref.watch(appVersionProvider);
    return WPScaffold(
        showBack: true,
        title: 'Preferences',
        child: ColoredBox(
            color: colors.surfaceContainerLowest,
            child:
                ListView(padding: const EdgeInsets.only(bottom: 16), children: [
              const SettingsHero(
                  title: 'Preferences',
                  subtitle: 'Customize your reading experience'),
              _section(Icons.palette_outlined, 'Appearance',
                  'Choose a look that feels comfortable.', [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final entry in {
                    ThemeMode.light: 'Light',
                    ThemeMode.dark: 'Dark',
                    ThemeMode.system: 'System'
                  }.entries)
                    ChoiceChip(
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 3),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                            fontSize: 12,
                            color: mode == entry.key
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface),
                        label: Text(entry.value),
                        selected: mode == entry.key,
                        onSelected: (_) => ref
                            .read(themeModeControllerProvider.notifier)
                            .setMode(entry.key)),
                ]),
                const Divider(height: 20),
                ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_android_outlined),
                    title: const Text('Follow Phone Settings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => ref
                        .read(themeModeControllerProvider.notifier)
                        .setMode(ThemeMode.system)),
              ]),
              _section(
                  Icons.text_fields_rounded,
                  'Text Size',
                  'Saved across the app. Your phone\'s accessibility text settings are also respected.',
                  [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final size in ReadingSize.values)
                        ChoiceChip(
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            labelPadding:
                                const EdgeInsets.symmetric(horizontal: 3),
                            backgroundColor: colors.surfaceContainerHighest,
                            selectedColor: colors.primary,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                                fontSize: 12,
                                color: reading.size == size
                                    ? Colors.white
                                    : colors.onSurface),
                            label: Text(size.label),
                            selected: reading.size == size,
                            onSelected: (_) => ref
                                .read(readingPreferencesProvider.notifier)
                                .setSize(size))
                    ]),
                  ]),
              _section(Icons.visibility_outlined, 'Live Preview', '', [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Ideas for a better wood industry',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        SizedBox(height: 5),
                        Text(
                            'Discover the latest news, people and innovations from Wood & Panel.',
                            style: TextStyle(fontSize: 13, height: 1.4)),
                      ])),
                  const SizedBox(width: 10),
                  ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/wallpapers/grain.png',
                          width: 65, height: 76, fit: BoxFit.cover)),
                ]),
              ]),
              _section(
                  Icons.notifications_outlined,
                  'Notifications',
                  'Receive alerts from either edition, wherever you are browsing.',
                  [
                    for (final edition in Edition.values)
                      SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Wood & Panel ${edition.label}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              'News and updates for ${edition.label}',
                              style: const TextStyle(fontSize: 11)),
                          secondary: Text(
                              edition == Edition.europe
                                  ? '\u{1F1EA}\u{1F1FA}'
                                  : '\u{1F1FA}\u{1F1F8}',
                              style: const TextStyle(fontSize: 22)),
                          value: push[edition] ?? false,
                          onChanged: _busy
                              ? null
                              : (value) async {
                                  setState(() => _busy = true);
                                  try {
                                    await ref
                                        .read(editionNavigationProvider)
                                        .setEditionEnabled(edition, value);
                                  } catch (_) {
                                    _message(
                                        'Could not save notification preferences. Please try again.');
                                  } finally {
                                    if (mounted) setState(() => _busy = false);
                                  }
                                }),
                    Text(ref.watch(notificationStatusProvider),
                        style: TextStyle(
                            color: colors.onSurfaceVariant, fontSize: 12)),
                  ]),
              _section(
                  Icons.headphones_outlined,
                  'Reading & Audio',
                  'Uses your phone\'s text-to-speech voices. No paid audio service is required.',
                  [
                    Text(
                        'Narration speed: ${(reading.speed / .45).toStringAsFixed(1)}x'),
                    Slider(
                        value: reading.speed,
                        min: .25,
                        max: .75,
                        divisions: 10,
                        label: '${(reading.speed / .45).toStringAsFixed(1)}x',
                        onChanged: (v) => ref
                            .read(readingPreferencesProvider.notifier)
                            .setSpeed(v)),
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Voice'),
                        subtitle: Text(reading.voice == null
                            ? 'Default English voice'
                            : '${reading.voice!['name']} (${reading.voice!['locale']})'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _voices),
                    OutlinedButton.icon(
                        onPressed: _preview,
                        icon: Icon(_previewing ? Icons.stop : Icons.play_arrow),
                        label: Text(_previewing
                            ? 'Stop preview'
                            : 'Listen to preview')),
                  ]),
              _section(Icons.shield_outlined, 'Privacy & Terms',
                  'Read the policies for the selected edition.', [
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Privacy Policy',
                        style: TextStyle(fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _legal(true)),
                const Divider(height: 1),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms & Conditions',
                        style: TextStyle(fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _legal(false)),
              ]),
              _section(Icons.info_outline, 'About the App',
                  'Wood & Panel - news, magazines and industry insights.', [
                Text(version.when(
                    data: (v) => 'Version ${v.version} (${v.buildNumber})',
                    loading: () => 'Loading app version...',
                    error: (_, __) => 'Version information unavailable')),
                const SizedBox(height: 8),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.support_agent),
                    title: const Text('Contact & Support'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _tts.stop();
                      context.push('/contact');
                    }),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.business_outlined),
                    title: const Text('About Wood & Panel'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _tts.stop();
                      context.push('/about');
                    }),
              ]),
            ])));
  }
}

class LegalPage extends ConsumerWidget {
  const LegalPage({super.key, required this.privacy});
  final bool privacy;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(activeConfigProvider);
    final title = privacy ? 'Privacy Policy' : 'Terms & Conditions';
    final content = privacy ? config.privacyPolicy : config.termsConditions;
    final sections = legalSections(content, title);
    return WPScaffold(
        showBack: true,
        title: title,
        child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child:
                ListView(padding: const EdgeInsets.only(bottom: 16), children: [
              SettingsHero(
                  title: title,
                  subtitle: privacy
                      ? 'Your privacy is important to us'
                      : 'Please read these terms carefully'),
              SettingsCard(
                  icon:
                      privacy ? Icons.lock_outline : Icons.description_outlined,
                  title: privacy ? 'Our Commitment' : 'Agreement',
                  description: '',
                  child: Text(sections.first.body,
                      style: const TextStyle(fontSize: 13, height: 1.45))),
              for (var i = 1; i < sections.length; i++)
                LegalSectionCard(
                    section: sections[i], index: i, privacy: privacy),
            ])));
  }
}
