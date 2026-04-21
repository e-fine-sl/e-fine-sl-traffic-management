// lib/services/police_locale_service.dart
//
// Manages the active locale for the Police module.
// Architecture: Mirrors the existing ThemeManager pattern (ValueNotifier) —
// zero new dependencies, fully consistent with the codebase.
//
// SOLID:
//  - Single Responsibility: only manages Police locale state.
//  - Open/Closed: add a new language by adding one entry to [availableLocales].

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class PoliceLocaleService {
  PoliceLocaleService._();
  static final PoliceLocaleService instance = PoliceLocaleService._();

  static const String _prefKey = 'police_locale';
  late SharedPreferences _prefs;

  final ValueNotifier<Locale> localeNotifier =
      ValueNotifier<Locale>(const Locale('en'));

  Map<String, dynamic> _translations = {};

  Locale get currentLocale => localeNotifier.value;

  static const List<PoliceLocaleOption> availableLocales = [
    PoliceLocaleOption(locale: Locale('en'), displayName: 'English', flagEmoji: '🇬🇧'),
    PoliceLocaleOption(locale: Locale('si'), displayName: 'සිංහල', flagEmoji: '🇱🇰'),
    PoliceLocaleOption(locale: Locale('ta'), displayName: 'தமிழ்', flagEmoji: '🇮🇳'),
  ];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedCode = _prefs.getString(_prefKey) ?? 'en';
    localeNotifier.value = Locale(savedCode);
    await _loadAsset(savedCode);
  }

  Future<void> _loadAsset(String langCode) async {
    try {
      final jsonString = await rootBundle.loadString('assets/translations/$langCode.json');
      _translations = json.decode(jsonString);
    } catch (e) {
      debugPrint("Failed to load translation for $langCode: $e");
      _translations = {};
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (currentLocale == locale) return;
    await _loadAsset(locale.languageCode);
    await _prefs.setString(_prefKey, locale.languageCode);
    localeNotifier.value = locale; // Triggers ValueListenableBuilder
  }

  PoliceLocaleOption get currentOption {
    return availableLocales.firstWhere(
      (opt) => opt.locale.languageCode == currentLocale.languageCode,
      orElse: () => availableLocales.first,
    );
  }

  String translate(String key) {
    List<String> keys = key.split('.');
    dynamic current = _translations;
    for (String k in keys) {
      if (current is Map<String, dynamic> && current.containsKey(k)) {
        current = current[k];
      } else {
        return key; // Fallback to key itself
      }
    }
    return current?.toString() ?? key;
  }
}
