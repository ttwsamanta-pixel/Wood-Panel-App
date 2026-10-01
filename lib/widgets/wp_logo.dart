import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WPLogo extends StatelessWidget {
  const WPLogo({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'logo.svg',
      height: height,
      semanticsLabel: 'Wood And Panel logo',
    );
  }
}
