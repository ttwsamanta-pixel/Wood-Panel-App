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
    final colors = Theme.of(context).colorScheme;
    return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: colors.outlineVariant.withValues(alpha: .45))),
        child: Material(
            color: Colors.transparent,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: colors.primary)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)))
              ]),
              const SizedBox(height: 10),
              Text(description,
                  style: TextStyle(color: colors.onSurfaceVariant)),
              const SizedBox(height: 12),
              ...children,
            ])));
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
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Text('Make it yours',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              const Text('Your reading experience, your way.'),
              const SizedBox(height: 20),
              _section(Icons.palette_outlined, 'Appearance',
                  'Choose a look that feels comfortable.', [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final entry in {
                    ThemeMode.light: 'Light',
                    ThemeMode.dark: 'Dark',
                    ThemeMode.system: 'Follow Phone Settings'
                  }.entries)
                    ChoiceChip(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                            color: mode == entry.key
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface),
                        label: Text(entry.value),
                        selected: mode == entry.key,
                        onSelected: (_) => ref
                            .read(themeModeControllerProvider.notifier)
                            .setMode(entry.key)),
                ]),
              ]),
              _section(
                  Icons.text_fields_rounded,
                  'Text Size',
                  'Saved across the app. Your phone\'s accessibility text settings are also respected.',
                  [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final size in ReadingSize.values)
                        ChoiceChip(
                            backgroundColor: colors.surfaceContainerHighest,
                            selectedColor: colors.primary,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                                color: reading.size == size
                                    ? Colors.white
                                    : colors.onSurface),
                            label: Text(size.label),
                            selected: reading.size == size,
                            onSelected: (_) => ref
                                .read(readingPreferencesProvider.notifier)
                                .setSize(size))
                    ]),
                    const SizedBox(height: 16),
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: .06),
                            borderRadius: BorderRadius.circular(14)),
                        child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('LIVE PREVIEW',
                                  style: TextStyle(
                                      fontSize: 11, letterSpacing: 1.4)),
                              SizedBox(height: 8),
                              Text('Ideas for a better wood industry',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                              SizedBox(height: 6),
                              Text(
                                  'Discover the latest news, people and innovations from Wood & Panel.',
                                  style: TextStyle(fontSize: 14, height: 1.5)),
                            ])),
                  ]),
              _section(
                  Icons.notifications_outlined,
                  'Notifications',
                  'Receive alerts from either edition, wherever you are browsing.',
                  [
                    for (final edition in Edition.values)
                      SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Wood & Panel ${edition.label}'),
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
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _legal(true)),
                const Divider(height: 1),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Terms & Conditions'),
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
    return WPScaffold(
        showBack: true,
        title: title,
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Wood & Panel ${config.edition.label}',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 16),
              SelectableText(content,
                  style: Theme.of(context).textTheme.bodyLarge),
            ])));
  }
}
