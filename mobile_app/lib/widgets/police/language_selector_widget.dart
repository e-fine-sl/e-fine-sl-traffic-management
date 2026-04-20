// lib/widgets/police/language_selector_widget.dart
//
// A self-contained AppBar action widget for Police screens.
// Renders a globe icon; on tap shows a popup menu with all supported locales.
// Calls PoliceLocaleService.setLocale — no direct setState in parent needed.
//
// SOLID:
//  - Single Responsibility: only handles language-selection UI.
//  - Open/Closed: new languages appear automatically from PoliceLocaleService.

import 'package:flutter/material.dart';
import '../../services/police_locale_service.dart';

class LanguageSelectorWidget extends StatelessWidget {
  const LanguageSelectorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: PoliceLocaleService.instance.localeNotifier,
      builder: (context, currentLocale, _) {
        return PopupMenuButton<Locale>(
          // Globe icon — universally recognised as language selector.
          icon: const Icon(Icons.language, color: Colors.white),
          tooltip: 'Select Language',
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          // Build one item per supported locale.
          itemBuilder: (context) {
            return PoliceLocaleService.availableLocales.map((option) {
              final bool isActive =
                  option.locale.languageCode == currentLocale.languageCode;
              return PopupMenuItem<Locale>(
                value: option.locale,
                child: Row(
                  children: [
                    Text(
                      option.flagEmoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        option.displayName,
                        style: TextStyle(
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                    ),
                    if (isActive)
                      Icon(
                        Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                  ],
                ),
              );
            }).toList();
          },
          // On selection: delegate to the service (async, safe with mounted check).
          onSelected: (Locale selected) async {
            if (context.mounted) {
              await PoliceLocaleService.instance.setLocale(context, selected);
            }
          },
        );
      },
    );
  }
}
