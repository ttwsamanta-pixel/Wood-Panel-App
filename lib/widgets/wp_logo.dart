import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/edition/edition.dart';

class WPLogo extends ConsumerWidget {
  const WPLogo({super.key, this.height = 28, this.width, this.edition});

  final double height;
  final double? width;
  final Edition? edition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Edition selected = edition ?? ref.watch<Edition>(editionProvider);
    final config = ref.watch(editionConfigProvider(selected)).valueOrNull ??
        EditionConfig(edition: selected);
    if (config.logoUrl.isNotEmpty) {
      final uri = Uri.tryParse(config.logoUrl);
      if (uri?.scheme == 'https') {
        if (uri!.path.toLowerCase().endsWith('.svg')) {
          return SvgPicture.network(config.logoUrl,
              height: height, width: width, fit: BoxFit.contain);
        }
        return Image.network(config.logoUrl,
            height: height,
            width: width,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Text('Wood & Panel ${config.edition.label}'));
      }
    }
    if (config.edition == Edition.usa) {
      return SvgPicture.asset('assets/logo_usa.svg',
          height: height, width: width, fit: BoxFit.contain);
    }
    return SvgPicture.asset(
      'logo.svg',
      height: height,
      width: width,
      fit: BoxFit.contain,
      semanticsLabel: 'Wood And Panel logo',
    );
  }
}
