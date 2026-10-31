import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReadingSize {
  small('Small', .9),
  normal('Default', 1),
  large('Large', 1.15),
  extraLarge('Extra Large', 1.3);

  const ReadingSize(this.label, this.scale);
  final String label;
  final double scale;
}

class ReadingPreferences {
  const ReadingPreferences(
      {this.size = ReadingSize.normal, this.speed = .45, this.voice});
  final ReadingSize size;
  final double speed;
  final Map<String, String>? voice;
}

final readingPreferencesProvider =
    StateNotifierProvider<ReadingPreferencesController, ReadingPreferences>(
        (ref) => ReadingPreferencesController());

class ReadingPreferencesController extends StateNotifier<ReadingPreferences> {
  ReadingPreferencesController() : super(const ReadingPreferences()) {
    ready = _load();
  }
  late final Future<void> ready;
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, String>? voice;
    try {
      final raw = jsonDecode(prefs.getString('reading_voice') ?? 'null');
      if (raw is Map && raw['name'] is String && raw['locale'] is String) {
        voice = {'name': raw['name'], 'locale': raw['locale']};
      }
    } catch (_) {/* Ignore an unavailable saved voice. */}
    if (!mounted) return;
    state = ReadingPreferences(
        size: ReadingSize.values.firstWhere(
            (s) => s.name == prefs.getString('reading_size'),
            orElse: () => ReadingSize.normal),
        speed: (prefs.getDouble('reading_speed') ?? .45).clamp(.25, .75),
        voice: voice);
  }

  Future<void> setSize(ReadingSize size) async {
    await ready;
    if (!mounted) return;
    state =
        ReadingPreferences(size: size, speed: state.speed, voice: state.voice);
    await (await SharedPreferences.getInstance())
        .setString('reading_size', size.name);
  }

  Future<void> setSpeed(double speed) async {
    await ready;
    if (!mounted) return;
    final value = speed.clamp(.25, .75);
    state =
        ReadingPreferences(size: state.size, speed: value, voice: state.voice);
    await (await SharedPreferences.getInstance())
        .setDouble('reading_speed', value);
  }

  Future<void> setVoice(Map<String, String>? voice) async {
    await ready;
    if (!mounted) return;
    state =
        ReadingPreferences(size: state.size, speed: state.speed, voice: voice);
    await (await SharedPreferences.getInstance())
        .setString('reading_voice', jsonEncode(voice));
  }
}

// Preserve the phone's accessibility scaling, including nonlinear scaling.
class ReadingTextScaler extends TextScaler {
  const ReadingTextScaler(this.phone, this.multiplier);
  final TextScaler phone;
  final double multiplier;
  @override
  double scale(double fontSize) => phone.scale(fontSize) * multiplier;
  @override
  double get textScaleFactor => phone.scale(14) / 14 * multiplier;
}

Future<void> applyReadingVoice(
    FlutterTts tts, ReadingPreferences preferences) async {
  await tts.setSpeechRate(preferences.speed);
  await tts.setLanguage('en-US');
  final voice = preferences.voice;
  if (voice != null) {
    try {
      final voices = await tts.getVoices;
      if (voices is List &&
          voices.any((v) =>
              v is Map &&
              v['name'] == voice['name'] &&
              v['locale'] == voice['locale'])) {
        await tts.setVoice(voice);
      }
    } catch (_) {
      /* Use the device's English voice if the saved voice was removed. */
    }
  }
}
