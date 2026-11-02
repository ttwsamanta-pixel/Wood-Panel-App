import 'package:flutter/material.dart';
import '../../widgets/wp_logo.dart';
import 'availability.dart';
import 'edition.dart';

/// Presentation shared by the three access states; policy stays in the gate.
class AvailabilityScreen extends StatelessWidget {
  const AvailabilityScreen(
      {super.key,
      required this.edition,
      required this.access,
      required this.message,
      this.error,
      required this.onRetry,
      required this.onUpdate,
      required this.onOtherEdition,
      required this.onLater});
  final Edition edition;
  final AccessState access;
  final String message;
  final String? error;
  final VoidCallback onRetry, onUpdate, onOtherEdition, onLater;

  @override
  Widget build(BuildContext context) {
    final maintenance = access == AccessState.maintenance;
    final usa = edition == Edition.usa;
    final accent = usa ? const Color(0xffa51c28) : const Color(0xffaa480b);
    final green = usa ? const Color(0xff222f64) : const Color(0xff005339);
    final action = maintenance ? accent : green;
    final text = Theme.of(context).textTheme;
    Widget button(String label, IconData icon, VoidCallback callback,
            {bool outline = false}) =>
        Container(
            width: double.infinity,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: outline
                    ? null
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                            action,
                            Color.lerp(action, Colors.black, .22)!
                          ]),
                border: outline ? Border.all(color: action, width: 1.3) : null),
            child: TextButton.icon(
                onPressed: callback,
                style: TextButton.styleFrom(
                    foregroundColor: outline ? action : Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 13, horizontal: 12)),
                icon: Icon(icon, size: 27),
                label: Text(label,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600))));
    return Scaffold(
        backgroundColor: const Color(0xfffffcf8),
        body: LayoutBuilder(builder: (context, constraints) {
          final h = constraints.maxHeight;
          final artHeight = (h * (maintenance ? .27 : .29)).clamp(155.0, 330.0);
          return Stack(children: [
            if (!maintenance)
              Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: h * .49,
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                        Color.lerp(green, Colors.black, .4)!,
                        green,
                        const Color(0xffaac9b4)
                      ])))),
            Positioned(
                top: 0,
                right: maintenance ? 0 : null,
                left: maintenance ? null : 0,
                child: Transform.flip(
                    flipX: !maintenance,
                    child: const _WoodTrim(width: 140, height: 100))),
            if (!maintenance)
              Positioned(
                  top: h * .44,
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: const DecoratedBox(
                      decoration: BoxDecoration(
                          color: Color(0xfffffcf8),
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(44))))),
            SafeArea(
                child: SingleChildScrollView(
                    child: ConstrainedBox(
                        constraints: BoxConstraints(
                            minHeight:
                                h - MediaQuery.paddingOf(context).vertical),
                        child: Center(
                            child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 520),
                                child: Column(children: [
                                  SizedBox(
                                      height: (h * .065).clamp(20.0, 70.0)),
                                  WPLogo(
                                      edition: edition, width: 220, height: 68),
                                  SizedBox(height: maintenance ? 22 : 28),
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 30),
                                      child: Image.asset(
                                          maintenance
                                              ? 'assets/pages/maintenance-illustration.png'
                                              : 'assets/pages/update-illustration.png',
                                          height: artHeight,
                                          fit: BoxFit.contain,
                                          excludeFromSemantics: true)),
                                  Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.fromLTRB(
                                          26, 18, 26, 20),
                                      decoration: BoxDecoration(
                                          color: maintenance
                                              ? null
                                              : const Color(0xfffffcf8),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(44))),
                                      child: Column(children: [
                                        if (maintenance) ...[
                                          Text('${edition.label} is under',
                                              textAlign: TextAlign.center,
                                              style: text.titleLarge?.copyWith(
                                                  fontSize: 30,
                                                  height: 1.1,
                                                  fontWeight: FontWeight.w800,
                                                  color:
                                                      const Color(0xff362217))),
                                          Text('Maintenance',
                                              style: text.titleLarge?.copyWith(
                                                  fontSize: 35,
                                                  height: 1.2,
                                                  fontWeight: FontWeight.w800,
                                                  color: accent)),
                                        ] else
                                          Text(
                                              access ==
                                                      AccessState.requiredUpdate
                                                  ? 'Update required'
                                                  : 'Update available',
                                              textAlign: TextAlign.center,
                                              style: text.titleLarge?.copyWith(
                                                  fontSize: 31,
                                                  height: 1.15,
                                                  fontWeight: FontWeight.w800,
                                                  color: green)),
                                        const SizedBox(height: 16),
                                        Container(
                                            width: 72,
                                            height: 4,
                                            decoration: BoxDecoration(
                                                color: accent.withValues(
                                                    alpha: .25),
                                                borderRadius:
                                                    BorderRadius.circular(4)),
                                            alignment: Alignment.center,
                                            child: Container(
                                                width: 40,
                                                decoration: BoxDecoration(
                                                    color: accent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4)))),
                                        const SizedBox(height: 18),
                                        Text(message,
                                            textAlign: TextAlign.center,
                                            style: text.bodyLarge?.copyWith(
                                                fontSize: 18,
                                                height: 1.45,
                                                color:
                                                    const Color(0xff505050))),
                                        const SizedBox(height: 26),
                                        button(
                                            maintenance
                                                ? 'Retry'
                                                : 'Update now',
                                            maintenance
                                                ? Icons.refresh_rounded
                                                : Icons.download_rounded,
                                            maintenance ? onRetry : onUpdate),
                                        const SizedBox(height: 13),
                                        button(
                                            maintenance
                                                ? 'Open ${usa ? 'Europe' : 'USA'} edition'
                                                : 'Retry',
                                            maintenance
                                                ? Icons.language
                                                : Icons.refresh_rounded,
                                            maintenance
                                                ? onOtherEdition
                                                : onRetry,
                                            outline: true),
                                        if (error != null)
                                          Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 12),
                                              child: Text(error!,
                                                  style: TextStyle(
                                                      color: accent))),
                                        if (access ==
                                            AccessState.optionalUpdate)
                                          TextButton(
                                              onPressed: onLater,
                                              child: Text('Later',
                                                  style: TextStyle(
                                                      color: green,
                                                      fontSize: 21,
                                                      fontWeight:
                                                          FontWeight.w700))),
                                      ])),
                                  Transform.flip(
                                      flipY: true,
                                      child: _WoodTrim(
                                          width: constraints.maxWidth,
                                          height: 75)),
                                ])))))),
          ]);
        }));
  }
}

class _WoodTrim extends StatelessWidget {
  const _WoodTrim({required this.width, required this.height});
  final double width, height;
  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: ClipPath(
          clipper: _Wave(),
          child: Image.asset('assets/wallpapers/grain.png',
              width: width, height: height, fit: BoxFit.cover)));
}

class _Wave extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height)
    ..cubicTo(s.width * .7, s.height * .95, s.width * .55, s.height * .08, 0, 0)
    ..close();
  @override
  bool shouldReclip(_Wave oldClipper) => false;
}
