// lib/services/police_locale_service.dart
//
// Manages the active locale for the Police module.
// Architecture: Mirrors the existing ThemeManager pattern (ValueNotifier) —
// zero new dependencies, fully consistent with the codebase.
//
// SOLID:
//  - Single Responsibility: only manages Police locale state.
//  - Open/Closed: add a new language by adding one entry to [availableLocales].

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// A simple data class describing a supported locale with a human-readable label.
class PoliceLocaleOption {
  final Locale locale;
  final String displayName;
  final String flagEmoji;

  const PoliceLocaleOption({
    required this.locale,
    required this.displayName,
    required this.flagEmoji,
  });
}

/// Singleton service that holds the active [Locale] for Police screens.
/// Screens listen via [ValueListenableBuilder] or simply call [setLocale].
class PoliceLocaleService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  PoliceLocaleService._();
  static final PoliceLocaleService instance = PoliceLocaleService._();

  // ── State ───────────────────────────────────────────────────────────────────
  /// Reactive locale notifier — wrap in [ValueListenableBuilder] if needed.
  final ValueNotifier<Locale> localeNotifier =
      ValueNotifier<Locale>(const Locale('en'));

  Locale get currentLocale => localeNotifier.value;

  // ── Supported locales ───────────────────────────────────────────────────────
  /// The authoritative list of locales available to Police officers.
  /// To add a new language: add a JSON file in assets/translations/ and
  /// append an entry here — no other changes required.
  static const List<PoliceLocaleOption> availableLocales = [
    PoliceLocaleOption(
      locale: Locale('en'),
      displayName: 'English',
      flagEmoji: '🇬🇧',
    ),
    PoliceLocaleOption(
      locale: Locale('si'),
      displayName: 'සිංහල',
      flagEmoji: '🇱🇰',
    ),
    PoliceLocaleOption(
      locale: Locale('ta'),
      displayName: 'தமிழ்',
      flagEmoji: '🇮🇳',
    ),
  ];

  // ── API ─────────────────────────────────────────────────────────────────────
  /// Switch the app locale and update the internal notifier.
  ///
  /// Calls [context.setLocale] from easy_localization — this triggers a full
  /// widget tree rebuild for all Text widgets using .tr(), so there is no
  /// need for additional setState calls in the callers.
  Future<void> setLocale(BuildContext context, Locale locale) async {
    if (currentLocale == locale) return; // No-op: already active.
    await context.setLocale(locale);
    localeNotifier.value = locale;
  }

  /// Convenience getter: the [PoliceLocaleOption] matching the current locale,
  /// or the first entry as a safe fallback (enforces non-null).
  PoliceLocaleOption get currentOption {
    return availableLocales.firstWhere(
      (opt) => opt.locale.languageCode == currentLocale.languageCode,
      orElse: () => availableLocales.first,
    );
  }
}
