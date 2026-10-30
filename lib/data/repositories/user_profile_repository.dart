import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_api_repository.dart';

class UserProfile {
  const UserProfile({this.name = '', this.email = '', this.photo = ''});
  final String name, email, photo;
  String get displayName => name.trim().isEmpty ? 'User' : name;
  Map<String, String> toJson() =>
      {'name': name, 'email': email, 'photo': photo};
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      photo: json['photo'] as String? ?? '');
}

final userProfileProvider =
    AsyncNotifierProvider<UserProfileController, UserProfile>(
        UserProfileController.new);

class UserProfileController extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      return UserProfile.fromJson(
          jsonDecode(prefs.getString('user_profile_v1') ?? '{}'));
    } catch (_) {
      return const UserProfile();
    }
  }

  Future<void> save(UserProfile profile) async {
    final api = ref.read(appApiRepositoryProvider);
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString('user_profile_token_v1');
    if (token == null) {
      final random = Random.secure();
      token = List.generate(
              32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
          .join();
      await prefs.setString('user_profile_token_v1', token);
    }
    await api.saveProfile(
        name: profile.name,
        email: profile.email,
        photo: profile.photo,
        token: token);
    await prefs.setString('user_profile_v1', jsonEncode(profile.toJson()));
    await prefs.setBool('profile_prompt_seen_v1', true);
    state = AsyncData(profile);
  }

  Future<void> skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('profile_prompt_seen_v1', true);
  }
}

String profileGreeting([DateTime? time]) {
  final hour = (time ?? DateTime.now()).hour;
  return hour < 12
      ? 'Good Morning,'
      : hour < 17
          ? 'Good Afternoon,'
          : 'Good Evening,';
}
