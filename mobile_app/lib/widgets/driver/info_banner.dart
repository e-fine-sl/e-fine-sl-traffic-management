import 'package:flutter/material.dart';

/// A compact, professional inline notice banner.
///
/// Used to display informational (GPS location), warning (misuse),
/// or error messages in a uniform, non-intrusive way.
class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final InfoBannerVariant variant;

  const InfoBanner({
    super.key,
    required this.icon,
    required this.text,
    this.variant = InfoBannerVariant.info,
  });

  @override
  Widget build(BuildContext context) {
    final _BannerStyle style = _getStyle(variant);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: style.iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                color: style.textColor,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _BannerStyle _getStyle(InfoBannerVariant v) {
    switch (v) {
      case InfoBannerVariant.info:
        return _BannerStyle(
          background: const Color(0xFFF0F5FF), // very subtle blue
          iconColor: const Color(0xFF3B82F6),
          textColor: const Color(0xFF475569),
        );
      case InfoBannerVariant.warning:
        return _BannerStyle(
          background: const Color(0xFFFFFBEB), // very subtle amber
          iconColor: const Color(0xFFF59E0B),
          textColor: const Color(0xFF78592B),
        );
      case InfoBannerVariant.error:
        return _BannerStyle(
          background: const Color(0xFFFEF2F2),
          iconColor: const Color(0xFFEF4444),
          textColor: const Color(0xFFB91C1C),
        );
    }
  }
}

enum InfoBannerVariant { info, warning, error }

class _BannerStyle {
  final Color background;
  final Color iconColor;
  final Color textColor;

  const _BannerStyle({
    required this.background,
    required this.iconColor,
    required this.textColor,
  });
}
