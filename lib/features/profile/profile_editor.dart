import 'package:flutter/material.dart';
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
        child: Icon(Icons.person,
            size: radius * 1.3, color: Theme.of(context).colorScheme.primary));
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
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

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
      await ref.read(userProfileProvider.notifier).save(
          UserProfile(name: _name.text.trim(), email: _email.text.trim()));
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
                      const Center(
                          child: ProfileAvatar(
                              profile: UserProfile(), radius: 48)),
                      const SizedBox(height: 24),
                      Form(
                          key: _form,
                          child: Column(children: [
                            TextFormField(
                                controller: _name,
                                maxLength: 100,
                                decoration: const InputDecoration(
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
                                decoration: const InputDecoration(
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
                          'Submitting saves your name and email to this edition’s website. This is an app profile, not a sign-in account.',
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
