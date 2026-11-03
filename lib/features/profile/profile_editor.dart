import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../data/repositories/app_preferences_repository.dart';
import '../../widgets/wp_logo.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.radius = 38});
  final UserProfile profile;
  final double radius;
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
        radius: radius,
        backgroundColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: .12),
        child: RegExp(r'^avatar_(10|[1-9])$').hasMatch(profile.avatar)
            ? ClipOval(
                child: SvgPicture.asset('assets/avatars/${profile.avatar}.svg',
                    width: radius * 2, height: radius * 2))
            : Icon(Icons.person,
                size: radius * 1.3,
                color: Theme.of(context).colorScheme.primary));
  }
}

class ProfileEditor extends ConsumerStatefulWidget {
  const ProfileEditor({super.key, this.firstLaunch = false});
  final bool firstLaunch;
  @override
  ConsumerState<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<ProfileEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _email = TextEditingController();
  bool _busy = false, _loaded = false;
  String? _error;
  String _avatar = '';
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, IconData icon) =>
      InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE6DDD4))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE6DDD4))));

  Future<void> _next() async {
    if (!mounted) return;
    if (!widget.firstLaunch) {
      context.pop();
      return;
    }
    final done = await ref
        .read(appPreferencesRepositoryProvider)
        .hasCompletedOnboarding();
    if (mounted) context.go(done ? '/feed' : '/onboarding');
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(userProfileProvider.notifier).save(UserProfile(
          name: _name.text.trim(), email: _email.text.trim(), avatar: _avatar));
      await _next();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not save your profile. Please check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(userProfileProvider);
    if (!_loaded && saved.hasValue) {
      final p = saved.requireValue;
      _name.text = p.name;
      _email.text = p.email;
      _avatar = p.avatar;
      _loaded = true;
    }
    return Scaffold(
        backgroundColor: const Color(0xFFFAF7F2),
        appBar: AppBar(
            title: const WPLogo(height: 32),
            centerTitle: true,
            automaticallyImplyLeading: !widget.firstLaunch,
            actions: [
              if (widget.firstLaunch)
                TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await ref.read(userProfileProvider.notifier).skip();
                            await _next();
                          },
                    child: const Text('Skip'))
            ]),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child:
                        ListView(padding: const EdgeInsets.all(24), children: [
                      Text(
                          widget.firstLaunch
                              ? 'Welcome to Wood & Panel'
                              : 'Edit Profile',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 10),
                      const Text(
                          'Add your details to personalize your app. You can update them later from Profile.'),
                      const SizedBox(height: 24),
                      Center(
                          child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Color(0x18000000),
                                        blurRadius: 12,
                                        offset: Offset(0, 4))
                                  ]),
                              child: ProfileAvatar(
                                  profile: UserProfile(avatar: _avatar),
                                  radius: 64))),
                      const SizedBox(height: 20),
                      Text('Choose an Avatar',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: .15))),
                          child: GridView.count(
                              crossAxisCount: 5,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 8,
                              children: List.generate(10, (i) {
                                final id = 'avatar_${i + 1}';
                                final selected = id == _avatar;
                                return Semantics(
                                    label: 'Avatar ${i + 1}',
                                    selected: selected,
                                    button: true,
                                    child: InkWell(
                                        onTap: _busy
                                            ? null
                                            : () =>
                                                setState(() => _avatar = id),
                                        customBorder: const CircleBorder(),
                                        child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    width: 2,
                                                    color: selected
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                        : Colors.transparent)),
                                            child: Stack(children: [
                                              ClipOval(
                                                  child: SvgPicture.asset(
                                                      'assets/avatars/$id.svg')),
                                              if (selected)
                                                Align(
                                                    alignment:
                                                        Alignment.bottomRight,
                                                    child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(2),
                                                        decoration:
                                                            BoxDecoration(
                                                                shape: BoxShape
                                                                    .circle,
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .primary),
                                                        child: const Icon(
                                                            Icons.check,
                                                            color: Colors.white,
                                                            size: 13))),
                                            ]))));
                              }))),
                      const SizedBox(height: 24),
                      Form(
                          key: _form,
                          child: Column(children: [
                            TextFormField(
                                controller: _name,
                                maxLength: 100,
                                decoration: _fieldDecoration(
                                        'Name', Icons.person_outline)
                                    .copyWith(
                                        labelText: 'Name',
                                        prefixIcon: Icon(Icons.person_outline)),
                                validator: (v) => (v ?? '').trim().isEmpty
                                    ? 'Enter your name'
                                    : null),
                            const SizedBox(height: 12),
                            TextFormField(
                                controller: _email,
                                maxLength: 254,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _fieldDecoration(
                                        'Email', Icons.mail_outline)
                                    .copyWith(
                                        labelText: 'Email',
                                        prefixIcon: Icon(Icons.mail_outline)),
                                validator: (v) =>
                                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                            .hasMatch((v ?? '').trim())
                                        ? null
                                        : 'Enter a valid email'),
                          ])),
                      const SizedBox(height: 12),
                      const Text(
                          'Submitting saves your name and email to this edition’s website. Your avatar stays on this device only. This is an app profile, not a sign-in account.',
                          style: TextStyle(fontSize: 12)),
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(_error!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error))),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                          onPressed: _busy || !_loaded ? null : _save,
                          icon: const Icon(Icons.check),
                          label: Text(_busy ? 'Saving…' : 'Save Profile')),
                    ])))));
  }
}
