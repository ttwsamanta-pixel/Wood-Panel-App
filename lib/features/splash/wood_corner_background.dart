import 'package:flutter/material.dart';

/// Scalable veneer ribbons: only the opening splash uses this decoration.
class WoodCornerBackground extends CustomPainter {
  const WoodCornerBackground();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 400, size.height / 860);
    _corner(canvas);
    canvas.translate(400, 860);
    canvas.rotate(3.141592653589793);
    _corner(canvas);
    canvas.restore();
  }

  void _corner(Canvas canvas) {
    for (var layer = 0; layer < 3; layer++) {
      final reach = 195.0 - layer * 44;
      final depth = 200.0 - layer * 55;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(reach, 0)
        ..cubicTo(reach * .78, depth * .35, reach * .36, depth * .70, 0, depth)
        ..close();
      canvas.drawShadow(path, const Color(0xff9c6327), 10, false);
      canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: layer == 1
                  ? [
                      const Color(0xff27170e),
                      const Color(0xff6b3c1e),
                      const Color(0xff392114)
                    ]
                  : [
                      const Color(0xff4b2512),
                      const Color(0xffaa6a36),
                      const Color(0xff59301a)
                    ],
            ).createShader(Rect.fromLTWH(0, 0, reach, depth)));
      canvas.save();
      canvas.clipPath(path);
      for (var grain = -30; grain < 75; grain++) {
        final offset = grain * 5.0;
        final line = Path()
          ..moveTo(offset, -15)
          ..cubicTo(offset - 20, 55, offset - 90, 110, offset - 160, 220);
        canvas.drawPath(
            line,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = grain % 3 == 0 ? 1.4 : .55
              ..color = (grain.isEven
                      ? const Color(0xff1e1008)
                      : const Color(0xffe5ad71))
                  .withValues(alpha: .28));
      }
      canvas.restore();
      canvas.drawPath(
          Path()
            ..moveTo(reach, 0)
            ..cubicTo(
                reach * .78, depth * .35, reach * .36, depth * .70, 0, depth),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..shader = const LinearGradient(colors: [
              Color(0xff8f5729),
              Color(0xffffdc99),
              Color(0xffa46530)
            ]).createShader(Rect.fromLTWH(0, 0, reach, depth)));
    }
  }

  @override
  bool shouldRepaint(covariant WoodCornerBackground oldDelegate) => false;
}
