// ─────────────────────────────────────────────────────
// lib/config/app_constants.dart
// Central constants file for e-Fine SL Flutter app
// ─────────────────────────────────────────────────────

import 'package:flutter/material.dart';

// ── APP INFO ──────────────────────────────────────────
class AppInfo {
  static const String appName       = 'e-Fine SL';
  static const String appVersion    = '1.0.0';
  static const String appTagline    = 'Sri Lanka Traffic Fine Management';
}

// ── API ───────────────────────────────────────────────
class ApiConstants {
  // Main backend API (existing)
  static const String baseUrl       = 'https://e-fine-sl-traffic-management-1.onrender.com/api';
  // static const String baseUrl    = 'http://192.168.8.174:5000/api'; // local dev

  // Auth Microservice URL (update after Render deployment)
  static const String authServiceUrl = 'https://e-fine-sl-auth-service.onrender.com';
  // static const String authServiceUrl = 'http://192.168.8.174:4000'; // local dev

  static const String walletBaseUrl = 'https://efine-mock-data-loader.onrender.com/api/wallet';
  static const int    connectTimeout = 30000;
  static const int    receiveTimeout = 30000;
  static const String authPrefix    = 'Bearer';
  static const String payHereMerchantId = '1225301';
  static const String payHereNotifyUrl  = 'https://sandbox.payhere.lk/pay/checkout';
}

// ── USER ROLES ────────────────────────────────────────
class UserRoles {
  static const String admin  = 'admin';
  static const String officer = 'officer'; 
  static const String driver = 'driver';
}

// ── LICENSE/FINE STATUS ────────────────────────────────────
class AppStatus {
  static const String active    = 'ACTIVE';
  static const String suspended = 'SUSPENDED';
  static const String paid      = 'PAID';    // Must match backend exactly
  static const String unpaid    = 'UNPAID';  // Must match backend exactly
  static const String pending   = 'PENDING'; // Must match backend exactly
  static const String currency  = 'LKR';
}

// ── DEMERIT POINTS ────────────────────────────────────
class DemeritConstants {
  static const int    defaultPoints         = 24;
  static const int    suspensionThreshold   = 0;
  static const int    monthlyRestorePoints  = 2;
  static const int    minorOffensePoints    = 1;
  static const int    moderateOffensePoints = 3;
  static const int    seriousOffensePoints  = 6;
  static const int    criticalOffensePoints = 24;
}

// ── APP COLORS ────────────────────────────────────────
class AppColors {
  // Primary Settings
  static const Color primaryBlue    = Color(0xFF0D47A1);  // Police
  static const Color primaryBlueLight = Color(0xFF1565C0);
  static const Color primaryGreen   = Color(0xFF4CAF50);  // Driver primary
  static const Color primaryGreenDark = Color(0xFF388E3C);
  static const Color primaryGreenLight = Color(0xFFC8E6C9);

  // Status colors
  static const Color activeGreen    = Color(0xFF4CAF50);
  static const Color suspendedRed   = Color(0xFFF44336);
  static const Color warningOrange  = Color(0xFFFF9800);
  static const Color dangerRed      = Color(0xFFF44336);

  // Demerit level colors
  static const Color goodStanding   = Color(0xFF4CAF50); // 70–100
  static const Color warningLevel   = Color(0xFFFF9800); // 40–69
  static const Color dangerLevel    = Color(0xFFF44336); // 0–39

  // UI colors
  static const Color background     = Color(0xFFF5F5F5);
  static const Color cardWhite      = Color(0xFFFFFFFF);
  static const Color textPrimary    = Color(0xFF212121);
  static const Color textSecondary  = Color(0xFF757575);
  static const Color textHint       = Color(0xFFBDBDBD);
  static const Color divider        = Color(0xFFEEEEEE);

  // Alert colors
  static const Color errorRed       = Color(0xFFD32F2F);
  static const Color successGreen   = Color(0xFF388E3C);
  static const Color infoBlueBg     = Color(0xFFE3F2FD);
  static const Color warningBg      = Color(0xFFFFF8E1);
  static const Color errorBg        = Color(0xFFFFEBEE);
  static const Color successBg      = Color(0xFFE8F5E9);
}

// ── TEXT STYLES / SIZES ───────────────────────────────
class AppTextSize {
  static const double heading1   = 24.0;
  static const double heading2   = 20.0;
  static const double heading3   = 18.0;
  static const double bodyLarge  = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall  = 12.0;
  static const double caption    = 10.0;
}

// ── SPACING & SIZING ──────────────────────────────────
class AppSpacing {
  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 16.0;
  static const double lg   = 24.0;
  static const double xl   = 32.0;
  static const double xxl  = 48.0;
}

// ── BORDER RADIUS ─────────────────────────────────────
class AppRadius {
  static const double small  = 8.0;
  static const double medium = 12.0;
  static const double large  = 16.0;
  static const double circle = 100.0;
}

// ── SHARED PREFERENCE KEYS ────────────────────────────
class PrefKeys {
  // Legacy token key (kept for backward compatibility)
  static const String authToken    = 'token';

  // New multi-token system
  static const String accessToken  = 'access_token';   // Short-lived JWT
  static const String refreshToken = 'refresh_token';  // Long-lived JWT
  static const String sessionToken = 'session_token';  // UUID session ID

  static const String userRole     = 'role';
  static const String userId       = 'userId';
  static const String userName     = 'name';
  static const String licenseNum   = 'licenseNumber';
  static const String badgeNumber  = 'badgeNumber';
  static const String position     = 'position';
  static const String profileImage = 'serverProfileImage';
  static const String user         = 'user';
  static const String profileData  = 'profile_data';
  static const String historyCache  = 'driver_history_cache';
  static const String idleTimeoutMinutes = 'idle_timeout_minutes';
}

// ── EXTERNAL MEDIA/ASSETS ───────────────────────────────────────
class AppAssets {
  static const String defaultProfileImage = 'https://cdn-icons-png.flaticon.com/512/206/206853.png';
  static const String logoCircle          = 'assets/icons/app_icon/app_logo_circle.png';
  static const String payhereLogo         = 'assets/images/payhere.png';
}

// ── LOCALIZATION ──────────────────────────────────────
class AppLocale {
  static const String defaultLang  = 'en';
  static const String sinhala      = 'si';
  static const List<String> supported = ['en', 'si'];
}

// ── DEMERIT LEVEL HELPER ──────────────────────────────
class DemeritLevel {
  static String getLabel(int points) {
    const max = DemeritConstants.defaultPoints;
    final ratio = points / max;

    if (ratio >= 1.0) return 'demerit_excellent';
    if (ratio >= 0.8) return 'demerit_good';
    if (ratio >= 0.6) return 'demerit_fair';
    if (ratio >= 0.4) return 'demerit_warning';
    if (ratio >  0.0) return 'demerit_danger';
    return 'demerit_suspended';
  }

  static Color getColor(int points) {
    const max = DemeritConstants.defaultPoints;
    final ratio = points / max;

    if (ratio >= 0.8) return AppColors.goodStanding;
    if (ratio >= 0.4) return AppColors.warningLevel;
    return AppColors.dangerLevel;
  }
}

// ── THEME-AWARE COLOR HELPERS ─────────────────────────
// Use these instead of hardcoded Colors.white / Colors.black54 etc.
// so every screen automatically adapts when the theme changes.
class AppTheme {
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Card / container background (white in light, dark card in dark)
  static Color cardBackground(BuildContext context) =>
      Theme.of(context).cardColor;

  /// Input field fill colour (light grey in light, dark grey in dark)
  static Color inputFill(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2C2C2C) : const Color(0xFFF2F2F2);

  /// Strong primary text (black87 / white)
  static Color textPrimary(BuildContext context) =>
      _isDark(context) ? Colors.white : const Color(0xDD000000); // black87

  /// Soft secondary text (black54 / white70)
  static Color textSecondary(BuildContext context) =>
      _isDark(context) ? Colors.white70 : Colors.black54;

  /// Hint / muted text (black38 / white38)
  static Color textHint(BuildContext context) =>
      _isDark(context) ? Colors.white38 : Colors.black38;

  /// Surface / drawer background (white / 0xFF1E1E1E)
  static Color drawerBackground(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1E1E1E) : Colors.white;

  /// Gauge track colour for the demerit arc background
  static Color gaugeTrack(BuildContext context) =>
      _isDark(context) ? const Color(0xFF3A3A3A) : Colors.grey.shade200;

  /// Divider colour
  static Color divider(BuildContext context) =>
      _isDark(context) ? const Color(0xFF3A3A3A) : const Color(0xFFEEEEEE);
}
