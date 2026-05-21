// ─────────────────────────────────────────────────────
// lib/services/secure_storage_service.dart
// Centralised FlutterSecureStorage service for e-Fine SL
// All persistent key/value operations go through this class.
// ─────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_constants.dart';

class SecureStorageService {
  static const String _tag = '[SecureStorageService]';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ──────────────────────────────────────────
  // PROFILE CACHE OPERATIONS
  // ──────────────────────────────────────────

  /// Encodes [data] to a JSON string and persists it under [PrefKeys.profileData].
  Future<void> cacheProfile(Map<String, dynamic> data) async {
    debugPrint('$_tag cacheProfile() called.');
    try {
      final jsonString = jsonEncode(data);
      await _storage.write(key: PrefKeys.profileData, value: jsonString);
      debugPrint('$_tag Profile cached successfully.');
    } catch (e) {
      debugPrint('$_tag Error caching profile: $e');
      rethrow;
    }
  }

  /// Reads and decodes the cached profile JSON.
  /// Returns [Map<String, dynamic>] on cache hit, or [null] on miss / error.
  Future<Map<String, dynamic>?> getCachedProfile() async {
    debugPrint('$_tag getCachedProfile() called.');
    try {
      final jsonString = await _storage.read(key: PrefKeys.profileData);
      if (jsonString == null || jsonString.isEmpty) {
        debugPrint('$_tag Cache miss — no profile stored.');
        return null;
      }
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      debugPrint('$_tag Cache hit — profile loaded from secure storage.');
      return decoded;
    } catch (e) {
      debugPrint('$_tag Error reading cached profile: $e');
      return null; // Treat parse errors as a cache miss
    }
  }

  /// Deletes only the cached profile entry.
  Future<void> clearCachedProfile() async {
    debugPrint('$_tag clearCachedProfile() called.');
    try {
      await _storage.delete(key: PrefKeys.profileData);
      debugPrint('$_tag Profile cache cleared.');
    } catch (e) {
      debugPrint('$_tag Error clearing profile cache: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────
  // AUTH TOKEN OPERATIONS
  // ──────────────────────────────────────────

  /// Returns the stored auth JWT token, or [null] if not present.
  Future<String?> getToken() async {
    debugPrint('$_tag getToken() called.');
    try {
      final token = await _storage.read(key: PrefKeys.authToken);
      if (token == null) {
        debugPrint('$_tag getToken() — no token found.');
      } else {
        debugPrint('$_tag getToken() — token retrieved successfully.');
      }
      return token;
    } catch (e) {
      debugPrint('$_tag Error reading token: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────
  // FULL AUTH CLEAR (called on logout)
  // ──────────────────────────────────────────

  /// Deletes ALL auth-related keys including the new 3-token system and biometric keys.
  /// Call this on every logout to ensure no stale data remains.
  Future<void> clearAllAuth() async {
    debugPrint('$_tag clearAllAuth() called — wiping all auth data...');
    try {
      await Future.wait([
        // Legacy token key
        _storage.delete(key: PrefKeys.authToken),
        // New 3-token system
        _storage.delete(key: PrefKeys.accessToken),
        _storage.delete(key: PrefKeys.refreshToken),
        _storage.delete(key: PrefKeys.sessionToken),
        // User data
        _storage.delete(key: PrefKeys.user),
        _storage.delete(key: PrefKeys.userRole),
        _storage.delete(key: PrefKeys.userName),
        _storage.delete(key: PrefKeys.profileData),
        // Biometric credentials
        _storage.delete(key: PrefKeys.biometricEnabled),
        _storage.delete(key: PrefKeys.biometricEmail),
        _storage.delete(key: PrefKeys.biometricPassword),
      ]);
      debugPrint('$_tag All auth data cleared successfully.');
    } catch (e) {
      debugPrint('$_tag Error clearing auth data: $e');
      rethrow;
    }
  }
}
