import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WPLogo extends StatelessWidget {
  const WPLogo({super.key, this.height = 28, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'logo.svg',
      height: height,
      width: width,
      fit: BoxFit.contain,
      semanticsLabel: 'Wood And Panel logo',
    );
  }
}
