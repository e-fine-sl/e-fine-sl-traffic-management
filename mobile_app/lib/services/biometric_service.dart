// ─────────────────────────────────────────────────────────────────────────────
// lib/services/biometric_service.dart
// e-Fine SL — Biometric Authentication Service
//
// Responsibilities:
//   1. Check if device hardware supports biometrics
//   2. Read/write the biometric-enabled flag from secure storage
//   3. Authenticate using local_auth (fingerprint / face ID)
//   4. Enable biometrics: verify credentials → store RSA-encrypted password
//   5. Disable biometrics: wipe all stored biometric keys
//   6. Login with biometrics: use stored credentials to do a full fresh login
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_constants.dart';
import 'auth_service.dart';

class BiometricService {
  static const String _tag = '[BiometricService]';

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final AuthService _authService = AuthService();

  // ─────────────────────────────────────────────────────────────────────────
  // DEVICE SUPPORT CHECK
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns true if the device has biometric hardware AND enrolled biometrics.
  Future<bool> isDeviceSupported() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        debugPrint('$_tag Device does not support biometrics.');
        return false;
      }
      final canCheck = await _localAuth.canCheckBiometrics;
      debugPrint('$_tag canCheckBiometrics: $canCheck');
      return canCheck;
    } catch (e) {
      debugPrint('$_tag Error checking device support: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ENABLED FLAG
  // ─────────────────────────────────────────────────────────────────────────

  /// Reads the biometric-enabled flag from secure storage.
  /// Returns true only if the value is explicitly 'true'.
  Future<bool> isBiometricEnabled() async {
    try {
      final val = await _storage.read(key: PrefKeys.biometricEnabled);
      final enabled = val == 'true';
      debugPrint('$_tag isBiometricEnabled: $enabled');
      return enabled;
    } catch (e) {
      debugPrint('$_tag Error reading biometric flag: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AUTHENTICATE (Local Hardware Prompt)
  // ─────────────────────────────────────────────────────────────────────────

  /// Shows the OS-level biometric prompt and returns whether it succeeded.
  /// [reason] is the localised message shown to the user on the prompt.
  Future<bool> authenticate({String reason = 'Verify your identity to continue'}) async {
    try {
      debugPrint('$_tag authenticate() called');
      final result = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,   // Allow device PIN/pattern as fallback
          stickyAuth: true,       // Keep prompt alive if app goes background
          useErrorDialogs: true,
        ),
      );
      debugPrint('$_tag authenticate() result: $result');
      return result;
    } catch (e) {
      debugPrint('$_tag Error during authentication: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ENABLE BIOMETRIC
  // ─────────────────────────────────────────────────────────────────────────

  /// Verifies the user's credentials via a fresh login, then stores them
  /// encrypted in secure storage and sets the biometric-enabled flag.
  ///
  /// Returns true on success, throws Exception with a user-friendly message
  /// on credential failure so the UI can show the error.
  Future<bool> enableBiometric({
    required String email,
    required String password,
  }) async {
    debugPrint('$_tag enableBiometric() — verifying credentials...');
    try {
      // Step 1: Verify credentials by doing a real login
      // This uses the existing RSA-encryption flow in AuthService
      await _authService.login(email, password);

      // Step 2: Store the email and RSA-encrypted password for future biometric logins
      final encryptedPassword = await _authService.encryptPasswordForBiometric(password);
      await _storage.write(key: PrefKeys.biometricEmail,    value: email);
      await _storage.write(key: PrefKeys.biometricPassword, value: encryptedPassword);
      await _storage.write(key: PrefKeys.biometricEnabled,  value: 'true');

      debugPrint('$_tag Biometric enabled successfully for: $email');
      return true;
    } on Exception catch (e) {
      debugPrint('$_tag enableBiometric() failed: $e');
      rethrow; // Bubble up the user-friendly message from AuthService
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DISABLE BIOMETRIC
  // ─────────────────────────────────────────────────────────────────────────

  /// Clears all biometric-related keys from secure storage.
  /// Called on manual disable (Settings) and automatically on logout.
  Future<void> disableBiometric() async {
    debugPrint('$_tag disableBiometric() — clearing biometric keys...');
    try {
      await Future.wait([
        _storage.delete(key: PrefKeys.biometricEnabled),
        _storage.delete(key: PrefKeys.biometricEmail),
        _storage.delete(key: PrefKeys.biometricPassword),
      ]);
      debugPrint('$_tag Biometric keys cleared.');
    } catch (e) {
      debugPrint('$_tag Error clearing biometric keys: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGIN WITH BIOMETRIC (Session Expired Path)
  // ─────────────────────────────────────────────────────────────────────────

  /// Reads the stored credentials and performs a full fresh login.
  /// Only called when the 2-day session has fully expired (not for
  /// token refresh within an active session).
  ///
  /// Returns the user map (role, name, etc.) on success.
  /// Throws Exception if stored credentials are missing or login fails.
  Future<Map<String, dynamic>> loginWithBiometric() async {
    debugPrint('$_tag loginWithBiometric() — fetching stored credentials...');

    final email    = await _storage.read(key: PrefKeys.biometricEmail);
    final encPassword = await _storage.read(key: PrefKeys.biometricPassword);

    if (email == null || encPassword == null) {
      debugPrint('$_tag Stored biometric credentials not found — disabling biometric.');
      await disableBiometric();
      throw Exception('Biometric credentials not found. Please log in manually.');
    }

    debugPrint('$_tag Found stored credentials for: $email — performing re-login...');
    try {
      // loginWithEncryptedPassword skips the RSA step since password is already encrypted
      final userData = await _authService.loginWithEncryptedPassword(email, encPassword);
      debugPrint('$_tag Biometric re-login successful — role: ${userData["role"]}');
      return userData;
    } catch (e) {
      debugPrint('$_tag Biometric re-login failed: $e');
      rethrow;
    }
  }
}
