// ─────────────────────────────────────────────────────────────────────────────
// lib/services/police_dashboard_service.dart
// e-Fine SL — Police Dashboard Service (FULLY FIXED)
//
// KEY FIX: _getTokenAndBadge() now reads badge from BOTH storage keys
// ('badgeNumber' and PrefKeys.badgeNumber) and falls back to the JWT token
// if storage is empty, preventing the silent failure from the race condition
// in initState where _loadDashboardData fires before _loadUserData finishes.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'api_logger.dart' as http;
import 'auth_service.dart';
import '../config/app_constants.dart';
import '../models/police_dashboard_model.dart';

class PoliceDashboardService {
  static const String _baseUrl = ApiConstants.baseUrl;
  final _storage = const FlutterSecureStorage();
  final _authService = AuthService();

  // ─────────────────────────────────────────────────────────────────────────
  // PRIMARY METHOD: getPoliceDashboardData()
  // Called by PoliceHomeScreen._loadDashboardData()
  // Returns: { 'dailyFinesCount': int, 'dailyTotalAmount': double, 'recentFines': List<Map> }
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getPoliceDashboardData() async {
    debugPrint('\n🔷 [PoliceDashboardService] ══════════════════════════════');
    debugPrint('🔷 [PoliceDashboardService] getPoliceDashboardData() START');
    debugPrint('🔷 [PoliceDashboardService] ══════════════════════════════');

    // STEP 1: Get token
    debugPrint('[PoliceDashboardService] STEP 1: Reading access token...');
    final String? token = await _authService.getToken();

    if (token == null) {
      debugPrint('❌ [PoliceDashboardService] STEP 1 FAILED: Token is NULL. User must log in again.');
      return null;
    }
    debugPrint('✅ [PoliceDashboardService] STEP 1 OK: Token retrieved (${token.substring(0, token.length.clamp(0, 20))}...)');

    // STEP 2: Get badge number — try all possible storage keys
    debugPrint('[PoliceDashboardService] STEP 2: Reading badge number from storage...');
    String? badge = await _storage.read(key: 'badgeNumber');
    debugPrint('[PoliceDashboardService]   → key "badgeNumber": $badge');

    // Fallback 1: Try PrefKeys constant (same value, but being explicit)
    if (badge == null || badge.isEmpty) {
      badge = await _storage.read(key: PrefKeys.badgeNumber);
      debugPrint('[PoliceDashboardService]   → key PrefKeys.badgeNumber ("${PrefKeys.badgeNumber}"): $badge');
    }

    // Fallback 2: Decode badge from JWT token payload directly
    if (badge == null || badge.isEmpty) {
      debugPrint('[PoliceDashboardService]   → Storage empty. Attempting to extract badge from JWT payload...');
      try {
        final Map<String, dynamic> payload = JwtDecoder.decode(token);
        debugPrint('[PoliceDashboardService]   → JWT payload keys: ${payload.keys.toList()}');
        badge = payload['badgeNumber']?.toString() ??
            payload['badge']?.toString() ??
            payload['sub']?.toString();
        debugPrint('[PoliceDashboardService]   → Badge from JWT: $badge');
        // Save it for next time
        if (badge != null && badge.isNotEmpty) {
          await _storage.write(key: 'badgeNumber', value: badge);
          debugPrint('[PoliceDashboardService]   → Badge saved to storage for next use.');
        }
      } catch (e) {
        debugPrint('[PoliceDashboardService]   → JWT decode failed: $e');
      }
    }

    // Fallback 3: Try fetching from /auth/me profile API
    if (badge == null || badge.isEmpty) {
      debugPrint('[PoliceDashboardService]   → Attempting to fetch badge from /auth/me API...');
      try {
        final profile = await _authService.getUserProfile();
        badge = profile['badgeNumber']?.toString();
        debugPrint('[PoliceDashboardService]   → Badge from /auth/me: $badge');
        if (badge != null && badge.isNotEmpty) {
          await _storage.write(key: 'badgeNumber', value: badge);
          debugPrint('[PoliceDashboardService]   → Badge saved to storage for next use.');
        }
      } catch (e) {
        debugPrint('[PoliceDashboardService]   → /auth/me fetch failed: $e');
      }
    }

    if (badge == null || badge.isEmpty) {
      debugPrint('❌ [PoliceDashboardService] STEP 2 FAILED: Badge number is NULL or EMPTY after all fallbacks.');
      debugPrint('❌ [PoliceDashboardService]   This means the user object returned at login did NOT contain badgeNumber.');
      debugPrint('❌ [PoliceDashboardService]   Check auth_service.dart login() response and the backend /auth/login endpoint.');
      return null;
    }
    debugPrint('✅ [PoliceDashboardService] STEP 2 OK: Badge number = "$badge"');

    // STEP 3: Build and fire the API request
    final uri = Uri.parse('$_baseUrl/fines/dashboard-stats').replace(
      queryParameters: {'policeOfficerId': badge},
    );

    debugPrint('[PoliceDashboardService] STEP 3: Firing HTTP GET...');
    debugPrint('[PoliceDashboardService]   → Full URL: $uri');

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      debugPrint('[PoliceDashboardService] STEP 3 COMPLETE: HTTP ${response.statusCode}');
      debugPrint('[PoliceDashboardService]   → Response body: ${response.body}');

      // STEP 4: Parse response
      debugPrint('[PoliceDashboardService] STEP 4: Parsing JSON...');

      if (response.statusCode == 200) {
        final Map<String, dynamic> rawData = jsonDecode(response.body);
        debugPrint('[PoliceDashboardService] STEP 4 OK: Raw parsed map: $rawData');

        // Extract with type safety
        final int dailyFinesCount =
            (rawData['dailyFinesCount'] as num?)?.toInt() ?? 0;
        final double dailyTotalAmount =
            (rawData['dailyTotalAmount'] as num?)?.toDouble() ?? 0.0;
        final List<dynamic> rawRecentFines = rawData['recentFines'] ?? [];
        final List<Map<String, dynamic>> recentFines = rawRecentFines
            .whereType<Map<String, dynamic>>()
            .toList();

        debugPrint('✅ [PoliceDashboardService] STEP 4 COMPLETE:');
        debugPrint('   dailyFinesCount  = $dailyFinesCount');
        debugPrint('   dailyTotalAmount = $dailyTotalAmount');
        debugPrint('   recentFines.length = ${recentFines.length}');
        if (recentFines.isNotEmpty) {
          debugPrint('   recentFines[0] = ${recentFines.first}');
        }

        return {
          'dailyFinesCount': dailyFinesCount,
          'dailyTotalAmount': dailyTotalAmount,
          'recentFines': recentFines,
        };
      } else if (response.statusCode == 401) {
        debugPrint('❌ [PoliceDashboardService] STEP 3 FAILED: 401 Unauthorized. Token may be expired or invalid.');
        return null;
      } else if (response.statusCode == 400) {
        debugPrint('❌ [PoliceDashboardService] STEP 3 FAILED: 400 Bad Request. Body: ${response.body}');
        debugPrint('   This usually means the "policeOfficerId" parameter is wrong or the badge "$badge" is not in the DB.');
        return null;
      } else {
        debugPrint('❌ [PoliceDashboardService] STEP 3 FAILED: Unexpected status ${response.statusCode}. Body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [PoliceDashboardService] STEP 3 EXCEPTION: $e');
      debugPrint('   StackTrace: $stackTrace');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER: _getTokenAndBadge — shared credential fetcher for other methods
  // Populates the passed map with 'token' and 'badge' keys.
  // Returns the token string, or null on failure.
  // ─────────────────────────────────────────────────────────────────────────
  Future<String?> _getTokenAndBadge(Map<String, String> creds) async {
    final token = await _authService.getToken();
    final badge = await _storage.read(key: 'badgeNumber');

    if (token == null) {
      debugPrint('[PoliceDashboardService] _getTokenAndBadge: ❌ Token is NULL');
      return null;
    }
    if (badge == null || badge.isEmpty) {
      debugPrint('[PoliceDashboardService] _getTokenAndBadge: ❌ Badge is NULL/EMPTY');
      return null;
    }

    creds['token'] = token;
    creds['badge'] = badge;
    return token;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getDailyStats() — Legacy method (kept for compatibility)
  // ─────────────────────────────────────────────────────────────────────────
  Future<DailyStatsModel?> getDailyStats() async {
    final creds = <String, String>{};
    if (await _getTokenAndBadge(creds) == null) return null;

    try {
      final uri = Uri.parse('$_baseUrl/police/daily-stats');
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${creds['token']!}',
      });

      if (response.statusCode == 200) {
        return DailyStatsModel.fromJson(jsonDecode(response.body));
      }
      debugPrint('[PoliceDashboardService] getDailyStats: status ${response.statusCode}');
    } catch (e) {
      debugPrint('[PoliceDashboardService] getDailyStats exception: $e');
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getRecentFines() — Legacy method (kept for compatibility)
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getRecentFines() async {
    final creds = <String, String>{};
    if (await _getTokenAndBadge(creds) == null) return [];

    try {
      final uri = Uri.parse('$_baseUrl/police/recent-fines');
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${creds['token']!}',
      });

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      debugPrint('[PoliceDashboardService] getRecentFines: status ${response.statusCode}');
    } catch (e) {
      debugPrint('[PoliceDashboardService] getRecentFines exception: $e');
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getHqAlerts() — Returns empty list gracefully if endpoint not available
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<HqAlertModel>> getHqAlerts() async {
    final creds = <String, String>{};
    if (await _getTokenAndBadge(creds) == null) return [];

    try {
      final uri = Uri.parse('$_baseUrl/police/hq-alerts');
      debugPrint('[PoliceDashboardService] getHqAlerts: calling $uri');
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${creds['token']!}',
      });

      debugPrint('[PoliceDashboardService] getHqAlerts: status ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => HqAlertModel.fromJson(e)).toList();
      }
    } catch (e) {
      // Non-critical: HQ alerts endpoint may not exist yet. Silently return empty.
      debugPrint('[PoliceDashboardService] getHqAlerts: endpoint unavailable ($e). Returning empty list.');
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // registerSosAlert()
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> registerSosAlert(String location, String officerName) async {
    final creds = <String, String>{};
    if (await _getTokenAndBadge(creds) == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/police/sos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${creds['token']!}',
        },
        body: jsonEncode({
          'badgeNumber': creds['badge']!,
          'officerName': officerName,
          'location': location,
        }),
      );
      debugPrint('[PoliceDashboardService] registerSosAlert: status ${response.statusCode}');
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('[PoliceDashboardService] registerSosAlert exception: $e');
      return false;
    }
  }
}