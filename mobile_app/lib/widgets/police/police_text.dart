import 'package:flutter/material.dart';
import '../../services/police_locale_service.dart';

/// Replaces standard `Text('key'.tr())` from easy_localization.
/// Automatically rebuilds only this leaf widget when the language changes,
/// bypassing the expensive `MaterialApp` full-tree rebuild lag.
class PoliceText extends StatelessWidget {
  final String textKey;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const PoliceText(
    this.textKey, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: PoliceLocaleService.instance.localeNotifier,
      builder: (context, _, __) {
        return Text(
          PoliceLocaleService.instance.translate(textKey),
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}
