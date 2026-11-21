import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

Future<ShareResult> shareText(BuildContext context, String text) =>
    Share.share(text, sharePositionOrigin: _shareOrigin(context));

Future<ShareResult> shareFile(BuildContext context, String path) =>
    Share.shareXFiles([XFile(path)], sharePositionOrigin: _shareOrigin(context));

Rect? _shareOrigin(BuildContext context) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
  final view = Offset.zero & MediaQuery.sizeOf(context);
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize && !box.size.isEmpty) {
    final visible = (box.localToGlobal(Offset.zero) & box.size).intersect(view);
    if (!visible.isEmpty) return visible;
  }
  return Rect.fromCenter(center: view.center, width: 1, height: 1);
}
