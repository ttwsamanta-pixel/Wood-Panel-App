import 'package:flutter/material.dart';

class BackToTop extends StatefulWidget {
  const BackToTop({super.key, required this.child});
  final Widget child;
  @override
  State<BackToTop> createState() => _BackToTopState();
}

class _BackToTopState extends State<BackToTop> {
  ScrollPosition? position;
  bool visible = false;
  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 &&
              notification.metrics.axis == Axis.vertical) {
            position = notification.context == null
                ? null
                : Scrollable.maybeOf(notification.context!)?.position;
            final next = notification.metrics.pixels > 240;
            if (next != visible) setState(() => visible = next);
          }
          return false;
        },
        child: Stack(children: [
          Positioned.fill(child: widget.child),
          if (visible)
            Positioned(
                right: 16,
                bottom: 18,
                child: FloatingActionButton.small(
                  heroTag: null,
                  tooltip: 'Back to top',
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                  onPressed: () => position?.animateTo(0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut),
                  child: const Icon(Icons.keyboard_arrow_up_rounded),
                )),
        ]),
      );
}
