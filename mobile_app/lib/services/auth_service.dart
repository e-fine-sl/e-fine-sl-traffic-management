// ─────────────────────────────────────────────────────────────────────────────
// lib/services/auth_service.dart
// e-Fine SL — Auth Service (UPDATED)
//
// Login flow:
//   1. Fetch RSA public key from auth-service
//   2. Encrypt password with RSA-OAEP before sending over network
//   3. POST to auth-service -> receive access_token, refresh_token, session_token
//   4. Store all 3 tokens in flutter_secure_storage
//   5. getToken() auto-refreshes access_token when expired
//   6. logout() calls auth-service to revoke session
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/oaep.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/asn1/asn1_parser.dart';
import 'package:pointycastle/asn1/primitives/asn1_bit_string.dart';
import 'package:pointycastle/asn1/primitives/asn1_integer.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';
import 'package:pointycastle/api.dart';

import 'api_logger.dart' as http;
import '../config/app_constants.dart';
// Note: BiometricService is NOT imported here to avoid a circular dependency.
// Biometric key cleanup is handled directly via _storage in _sessionExpiredLogout().

class AuthService {
  final String _mainUrl  = ApiConstants.baseUrl;         // main backend
  final String _authUrl  = ApiConstants.authServiceUrl;  // auth microservice
  final _storage = const FlutterSecureStorage();

  // ── Cache the RSA public key so we do not fetch it on every keystroke ────
  RSAPublicKey? _cachedPublicKey;

  // ─────────────────────────────────────────────────────────────────────────
  // TOKEN MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a VALID access token.
  /// If the stored access token is expired, automatically fetches a new one
  /// using the refresh token — transparent to the caller.
  Future<String?> getToken() async {
    // Check if the 2-day session has expired
    final startTimeStr = await _storage.read(key: PrefKeys.sessionStartTime);
    if (startTimeStr != null) {
      try {
        final startTime = DateTime.parse(startTimeStr);
        if (DateTime.now().difference(startTime).inDays >= 2) {
          debugPrint('[AuthService] 2-day session expired during getToken(). Session-expiry logout...');
          await _sessionExpiredLogout(); // Resets biometric dialog flag
          return null;
        }
      } catch (e) {
        debugPrint('[AuthService] Error checking session expiry in getToken(): $e');
      }
    }

    String? token = await _storage.read(key: PrefKeys.accessToken);
    if (token == null) return null;

    // Check if expired using jwt_decoder
    if (JwtDecoder.isExpired(token)) {
      debugPrint('[AuthService] Access token expired — refreshing...');
      try {
        token = await refreshAccessToken();
      } catch (e) {
        debugPrint('[AuthService] Refresh failed: $e');
        return null; // Caller gets 401, user must log in again
      }
    }
    return token;
  }

  /// Checks if the current session is active and has not exceeded the 2-day limit.
  /// If expired, it triggers a logout and returns null.
  /// If valid, it returns the user's role string.
  Future<String?> checkSession() async {
    try {
      final startTimeStr = await _storage.read(key: PrefKeys.sessionStartTime);
      final accessToken = await _storage.read(key: PrefKeys.accessToken);
      final role = await _storage.read(key: PrefKeys.userRole);

      if (startTimeStr == null || accessToken == null || role == null) {
        debugPrint('[AuthService] No active session found');
        return null;
      }

      final startTime = DateTime.parse(startTimeStr);
      final difference = DateTime.now().difference(startTime);

      if (difference.inDays >= 2) {
        debugPrint('[AuthService] Session expired (2 days reached). Session-expiry logout...');
        await _sessionExpiredLogout(); // Resets biometric dialog flag
        return null;
      }

      // Transparently refresh access token if it's expired but session is under 2 days
      if (JwtDecoder.isExpired(accessToken)) {
        debugPrint('[AuthService] Access token expired during checkSession, attempting refresh...');
        try {
          await refreshAccessToken();
        } catch (e) {
          debugPrint('[AuthService] Access token auto-refresh failed: $e. Session-expiry logout...');
          await _sessionExpiredLogout(); // Refresh failed = treat as session expiry
          return null;
        }
      }

      debugPrint('[AuthService] Session is valid. Role: $role');
      return role;
    } catch (e) {
      debugPrint('[AuthService] Error in checkSession: $e. Logging out...');
      await logout();
      return null;
    }
  }

  /// Calls auth-service /auth/refresh to get a new access token.
  /// Stores the new access token and returns it.
  Future<String> refreshAccessToken() async {
    final refreshToken = await _storage.read(key: PrefKeys.refreshToken);
    if (refreshToken == null) throw Exception('No refresh token — please log in again');

    final response = await http.post(
      Uri.parse('$_authUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newAccessToken = data['accessToken'] as String;
      await _storage.write(key: PrefKeys.accessToken, value: newAccessToken);
      debugPrint('[AuthService] Access token refreshed successfully');
      return newAccessToken;
    } else {
      throw Exception('Session expired — please log in again');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────────────────────────────────────

  /// Full login flow:
  ///   1. Fetch RSA public key from auth-service
  ///   2. RSA-OAEP encrypt the password on device
  ///   3. POST to auth-service with { email, encryptedPassword }
  ///   4. Store access_token, refresh_token, session_token securely
  ///   5. Return the user map (role, name, etc.) for navigation
  Future<Map<String, dynamic>> login(String email, String password) async {
    // Step 1: Fetch RSA public key
    final publicKey = await _fetchPublicKey();

    // Step 2: Encrypt password (never sent in plain text)
    final encryptedPassword = _encryptPassword(password, publicKey);

    // Step 3: Send login request to auth-service
    final response = await http.post(
      Uri.parse('$_authUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email':             email,
        'encryptedPassword': encryptedPassword,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;

      // Step 4: Store all 3 tokens securely
      await _storage.write(key: PrefKeys.accessToken,  value: data['accessToken']  as String);
      await _storage.write(key: PrefKeys.refreshToken, value: data['refreshToken'] as String);
      await _storage.write(key: PrefKeys.sessionToken, value: data['sessionToken'] as String);
      await _storage.write(key: PrefKeys.sessionStartTime, value: DateTime.now().toIso8601String());

      // Also store user info for quick access without an API call
      await _storage.write(key: PrefKeys.userName, value: user['name'] as String? ?? '');
      await _storage.write(key: PrefKeys.userRole, value: user['role'] as String? ?? '');

      if ((user['role'] as String?) == UserRoles.driver && user['licenseNumber'] != null) {
        await _storage.write(key: PrefKeys.licenseNum, value: user['licenseNumber'] as String);
      } else if (((user['role'] as String?) == UserRoles.officer || (user['role'] as String?) == UserRoles.admin) && user['badgeNumber'] != null) {
        await _storage.write(key: PrefKeys.badgeNumber, value: user['badgeNumber'] as String);
      }

      if ((user['role'] as String?) == UserRoles.officer || user['role'] == 'police') {
        if (user['badgeNumber'] != null) {
          await _storage.write(key: 'badgeNumber', value: user['badgeNumber'] as String);
        }
        if (user['_id'] != null || user['officerId'] != null) {
          await _storage.write(key: 'officerId', value: (user['officerId'] ?? user['_id']) as String);
        }
      }

      debugPrint('[AuthService] Login successful — role: ${user["role"]}');

      // Step 5: Store idle timeout minutes (non-sensitive setting)
      final prefs = await SharedPreferences.getInstance();
      final timeout = data['idleTimeoutMinutes'] ?? 5;
      await prefs.setInt(PrefKeys.idleTimeoutMinutes, timeout);
      debugPrint('[AuthService] Idle timeout set to: $timeout minutes');

      // Return the user map — login_screen.dart reads userData['role'] to navigate
      return user;
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Login Failed');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BIOMETRIC HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Encrypts [password] with RSA-OAEP and returns the Base64 result.
  /// Used by BiometricService to store the encrypted password securely.
  /// This keeps RSA logic centralised in AuthService.
  Future<String> encryptPasswordForBiometric(String password) async {
    final publicKey = await _fetchPublicKey();
    return _encryptPassword(password, publicKey);
  }

  /// Performs a full login using an already-RSA-encrypted password.
  /// Used by BiometricService.loginWithBiometric() to avoid double-encryption.
  /// The [encryptedPassword] is the Base64-encoded RSA-OAEP ciphertext.
  Future<Map<String, dynamic>> loginWithEncryptedPassword(
    String email,
    String encryptedPassword,
  ) async {
    debugPrint('[AuthService] loginWithEncryptedPassword() — biometric re-login for: $email');

    final response = await http.post(
      Uri.parse('$_authUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email':             email,
        'encryptedPassword': encryptedPassword, // Already RSA-encrypted
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;

      // Store fresh tokens
      await _storage.write(key: PrefKeys.accessToken,  value: data['accessToken']  as String);
      await _storage.write(key: PrefKeys.refreshToken, value: data['refreshToken'] as String);
      await _storage.write(key: PrefKeys.sessionToken, value: data['sessionToken'] as String);
      await _storage.write(key: PrefKeys.sessionStartTime, value: DateTime.now().toIso8601String());
      await _storage.write(key: PrefKeys.userName, value: user['name'] as String? ?? '');
      await _storage.write(key: PrefKeys.userRole, value: user['role'] as String? ?? '');

      // Restore biometric-enabled flag (it was cleared by deleteAll during expiry)
      await _storage.write(key: PrefKeys.biometricEnabled, value: 'true');

      final prefs = await SharedPreferences.getInstance();
      final timeout = data['idleTimeoutMinutes'] ?? 5;
      await prefs.setInt(PrefKeys.idleTimeoutMinutes, timeout);

      debugPrint('[AuthService] Biometric re-login successful — role: ${user["role"]}');
      return user;
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Biometric login failed — please log in manually');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRESENCE
  // ─────────────────────────────────────────────────────────────────────────

  /// Called by InteractionListener when app lifecycle changes
  Future<void> updatePresence(String state) async {
    final role = await _storage.read(key: PrefKeys.userRole);
    if (role != UserRoles.officer && role != 'police') return;

    final badgeNumber = await _storage.read(key: 'badgeNumber');
    if (badgeNumber == null) return;

    try {
      await http.put(
        Uri.parse('$_mainUrl/officer/presence'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'badgeNumber': badgeNumber,
          'state': state,
        }),
      );
    } catch (e) {
      debugPrint('[AuthService] Failed to update presence: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGOUT — TWO PATHS
  // ─────────────────────────────────────────────────────────────────────────

  /// MANUAL LOGOUT — User tapped the Logout button.
  /// Clears session secure storage (but PRESERVES biometric keys) and
  /// does NOT reset biometric_dialog_shown in SharedPreferences.
  /// This means the "Enable Biometric" dialog will NOT re-appear
  /// on the next login after a manual logout.
  Future<void> logout() async {
    debugPrint('[AuthService] logout() called — MANUAL LOGOUT');

    final sessionToken = await _storage.read(key: PrefKeys.sessionToken);

    // Revoke session on server (best-effort — do not fail if offline)
    if (sessionToken != null) {
      try {
        await http.post(
          Uri.parse('$_authUrl/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'sessionToken': sessionToken}),
        );
      } catch (e) {
        debugPrint('[AuthService] Session revocation failed (clean logout): $e');
      }
    }

    // Clear session and auth tokens but PRESERVE biometric keys!
    await Future.wait([
      _storage.delete(key: PrefKeys.accessToken),
      _storage.delete(key: PrefKeys.refreshToken),
      _storage.delete(key: PrefKeys.sessionToken),
      _storage.delete(key: PrefKeys.sessionStartTime),
      _storage.delete(key: PrefKeys.userRole),
      _storage.delete(key: PrefKeys.userName),
      _storage.delete(key: PrefKeys.user),
      _storage.delete(key: PrefKeys.profileData),
      _storage.delete(key: PrefKeys.authToken),
    ]);

    // Clear shared preferences EXCEPT biometric_dialog_shown
    final prefs = await SharedPreferences.getInstance();
    final dialogShown = prefs.getBool(PrefKeys.biometricDialogShown) ?? false;
    await prefs.clear();
    // Restore the dialog-shown flag so it won't pop up again after manual logout
    if (dialogShown) {
      await prefs.setBool(PrefKeys.biometricDialogShown, true);
    }

    _cachedPublicKey = null;
    debugPrint('[AuthService] Manual logout complete — biometric_dialog_shown preserved: $dialogShown');
  }

  /// SESSION-EXPIRY LOGOUT — Called automatically when the 2-day session expires
  /// or when the refresh token itself fails.
  /// Additionally resets biometric_dialog_shown to false so the dialog
  /// re-appears on the next credential login (fresh install / expiry behaviour).
  Future<void> _sessionExpiredLogout() async {
    debugPrint('[AuthService] _sessionExpiredLogout() called — SESSION EXPIRY');

    // Run the standard logout flow first
    final sessionToken = await _storage.read(key: PrefKeys.sessionToken);
    if (sessionToken != null) {
      try {
        await http.post(
          Uri.parse('$_authUrl/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'sessionToken': sessionToken}),
        );
      } catch (e) {
        debugPrint('[AuthService] Session revocation failed: $e');
      }
    }

    // Clear session and auth tokens but PRESERVE biometric keys!
    await Future.wait([
      _storage.delete(key: PrefKeys.accessToken),
      _storage.delete(key: PrefKeys.refreshToken),
      _storage.delete(key: PrefKeys.sessionToken),
      _storage.delete(key: PrefKeys.sessionStartTime),
      _storage.delete(key: PrefKeys.userRole),
      _storage.delete(key: PrefKeys.userName),
      _storage.delete(key: PrefKeys.user),
      _storage.delete(key: PrefKeys.profileData),
      _storage.delete(key: PrefKeys.authToken),
    ]);

    // Clear ALL shared preferences INCLUDING biometric_dialog_shown
    // so the "Enable Biometric" dialog shows again on next login
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Explicitly reset — in case clear() doesn't write a false value
    await prefs.setBool(PrefKeys.biometricDialogShown, false);

    _cachedPublicKey = null;
    debugPrint('[AuthService] Session-expiry logout complete — biometric_dialog_shown reset to false');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RSA ENCRYPTION HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches the RSA public key PEM from auth-service.
  /// Caches it in memory for the lifetime of the AuthService instance.
  Future<RSAPublicKey> _fetchPublicKey() async {
    if (_cachedPublicKey != null) return _cachedPublicKey!;

    final response = await http.get(
      Uri.parse('$_authUrl/auth/public-key'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch RSA public key from auth service');
    }

    final data      = jsonDecode(response.body);
    final pem       = data['publicKey'] as String;
    _cachedPublicKey = _parsePublicKeyFromPem(pem);
    return _cachedPublicKey!;
  }

  /// Parses an RSA SubjectPublicKeyInfo PEM string into a pointycastle RSAPublicKey.
  /// Works with pointycastle 3.x (PKCS#8 SubjectPublicKeyInfo format from openssl).
  RSAPublicKey _parsePublicKeyFromPem(String pem) {
    // Strip PEM headers/footers and whitespace, then decode from base64
    final base64Str = pem
        .replaceAll(RegExp(r'-----[^-]+-----'), '')
        .replaceAll(RegExp(r'\s'), '')
        .trim();

    final derBytes = Uint8List.fromList(base64.decode(base64Str));

    // Parse outer SEQUENCE — SubjectPublicKeyInfo
    final outerParser = ASN1Parser(derBytes);
    final outerSeq    = outerParser.nextObject() as ASN1Sequence;

    // Element [1] is a BIT STRING wrapping the actual RSA key SEQUENCE
    final bitString    = outerSeq.elements![1] as ASN1BitString;
    // valueBytes gives the raw bit-string content (skip the unused-bits byte)
    final innerBytes   = Uint8List.fromList(bitString.valueBytes!.skip(1).toList());

    // Parse inner SEQUENCE — RSAPublicKey { modulus, publicExponent }
    final innerParser = ASN1Parser(innerBytes);
    final innerSeq    = innerParser.nextObject() as ASN1Sequence;

    final modulus  = (innerSeq.elements![0] as ASN1Integer).integer!;
    final exponent = (innerSeq.elements![1] as ASN1Integer).integer!;

    return RSAPublicKey(modulus, exponent);
  }

  /// Encrypts [plainText] with RSA-OAEP using [publicKey].
  /// Returns a base64-encoded cipher string safe for JSON transmission.
  String _encryptPassword(String plainText, RSAPublicKey publicKey) {
    // OAEPEncoding with default SHA-1 digest — matches node-forge RSA-OAEP on backend
    final encryptor = OAEPEncoding(RSAEngine());
    encryptor.init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    final plainBytes    = Uint8List.fromList(utf8.encode(plainText));
    final encryptedBytes = encryptor.process(plainBytes);

    return base64.encode(encryptedBytes);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // USER PROFILE
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getUserProfile() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$_mainUrl/auth/me'),
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load profile');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PASSWORD RESET FLOWS (also use RSA encryption)
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$_mainUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to send OTP');
    }
    final body = jsonDecode(response.body);
    return body['role'] ?? 'Unknown';
  }

  Future<void> verifyResetOTP(String email, String otp) async {
    final response = await http.post(
      Uri.parse('$_mainUrl/auth/verify-reset-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    if (response.statusCode != 200) throw Exception('Invalid OTP');
  }

  /// Encrypts newPassword with RSA before sending to backend for reset.
  Future<void> resetPassword(String email, String newPassword, String otp) async {
    final publicKey          = await _fetchPublicKey();
    final encryptedPassword  = _encryptPassword(newPassword, publicKey);

    final response = await http.post(
      Uri.parse('$_mainUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email':       email,
        'newPassword': encryptedPassword, // encrypted
        'otp':         otp,
      }),
    );
    if (response.statusCode != 200) throw Exception('Failed to reset password');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // DRIVER LICENSE RECOVERY
  // ─────────────────────────────────────────────────────────────────────────────

  /// Step 1 — Look up a driver by license number.
  /// Returns masked driver info { name, maskedEmail, licenseNumber } for confirmation.
  Future<Map<String, dynamic>> lookupDriverByLicense(String licenseNumber) async {
    final response = await http.post(
      Uri.parse('$_mainUrl/auth/license-recovery/lookup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'licenseNumber': licenseNumber}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final body = jsonDecode(response.body);
    throw Exception(body['message'] ?? 'Driver not found with this license number');
  }

  /// Step 2 — Verify the scanned license number against the entered one.
  /// Returns { recoveryToken } on success.
  Future<String> verifyLicenseScan(String licenseNumber, String scannedLicenseNumber) async {
    final response = await http.post(
      Uri.parse('$_mainUrl/auth/license-recovery/verify-scan'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'licenseNumber':        licenseNumber,
        'scannedLicenseNumber': scannedLicenseNumber,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['recoveryToken'] as String;
    }
    final body = jsonDecode(response.body);
    throw Exception(body['message'] ?? 'License verification failed');
  }

  /// Step 3 — Reset driver password using the recovery token.
  /// RSA-encrypts newPassword before sending (same pattern as [resetPassword]).
  Future<void> resetPasswordByLicense(
    String licenseNumber,
    String recoveryToken,
    String newPassword,
  ) async {
    final publicKey         = await _fetchPublicKey();
    final encryptedPassword = _encryptPassword(newPassword, publicKey);

    final response = await http.post(
      Uri.parse('$_mainUrl/auth/license-recovery/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'licenseNumber':  licenseNumber,
        'recoveryToken':  recoveryToken,
        'newPassword':    encryptedPassword,
      }),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to reset password');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POLICE REGISTRATION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> requestVerification(String badgeNumber, String stationCode) async {
    final response = await http.post(
      Uri.parse('$_mainUrl/auth/request-verification'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'badgeNumber': badgeNumber, 'stationCode': stationCode}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to request OTP');
    }
  }

  Future<void> verifyOTP(String badgeNumber, String otp) async {
    final response = await http.post(
      Uri.parse('$_mainUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'badgeNumber': badgeNumber, 'otp': otp}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Invalid OTP');
    }
  }

  Future<List<Map<String, dynamic>>> getStations() async {
    try {
      final response = await http.get(Uri.parse('$_mainUrl/stations'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final List<dynamic> data = responseBody['data'] ?? [];
        return data.map((e) => {
          'name': e['name'],
          'code': e['stationCode'] ?? e['_id'],
        }).toList();
      }
      return _fallbackStations();
    } catch (_) {
      return _fallbackStations();
    }
  }

  List<Map<String, dynamic>> _fallbackStations() => [
    {'name': 'Colombo Fort', 'code': 'COL-01'},
    {'name': 'Maradana',     'code': 'COL-02'},
  ];

  /// Encrypts police password before sending for registration.
  Future<void> registerPolice(Map<String, dynamic> data) async {
    final publicKey = await _fetchPublicKey();
    if (data.containsKey('password')) {
      data['password'] = _encryptPassword(data['password'] as String, publicKey);
    }

    final response = await http.post(
      Uri.parse('$_mainUrl/auth/register-police'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Registration Failed');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DRIVER REGISTRATION
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> checkFieldExists(String field, String value, {String? role}) async {
    try {
      String url = '$_mainUrl/auth/check-exists?field=$field&value=${Uri.encodeComponent(value)}';
      if (role != null) {
        url += '&role=$role';
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['exists'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Verifies a driving license + NIC combination against the DMT database
  /// via the e-Fine SL backend proxy.
  ///
  /// Returns a Map with:
  ///   success (bool), found (bool), nicMatch (bool),
  ///   dmtUnreachable (bool), message (String), data (Map?) 
  Future<Map<String, dynamic>> verifyLicenseWithDMT({
    required String licenseNumber,
    required String nic,
  }) async {
    try {
      debugPrint('[AuthService] DMT verify: $licenseNumber / $nic');

      final response = await http.post(
        Uri.parse(ApiConstants.dmtVerifyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'licenseNumber': licenseNumber.trim().toUpperCase(),
          'nic':           nic.trim().toUpperCase(),
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      switch (response.statusCode) {
        case 200:
          return {
            'success':    true,
            'found':      true,
            'nicMatch':   true,
            'message':    data['message'] ?? 'Verified',
            'data':       data['data'],
          };
        case 404:
          return {
            'success':    false,
            'found':      false,
            'message':    data['message'] ?? 'License not found in DMT',
          };
        case 400:
          return {
            'success':    false,
            'found':      true,
            'nicMatch':   false,
            'message':    data['message'] ?? 'NIC does not match this license',
          };
        case 503:
          return {
            'success':        false,
            'dmtUnreachable': true,
            'message':        data['message'] ?? 'DMT service unavailable',
          };
        default:
          return {
            'success': false,
            'message': data['message'] ?? 'DMT verification failed',
          };
      }
    } catch (e) {
      debugPrint('[AuthService] DMT verify error: $e');
      return {
        'success':        false,
        'dmtUnreachable': true,
        'message':        'Unable to reach DMT verification service. Please try again.',
      };
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DRIVER EMAIL OTP VERIFICATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Sends a 6-digit OTP to the driver's email for verification during registration.
  Future<void> sendDriverEmailOTP(String email) async {
    final response = await http.post(
      Uri.parse('$_mainUrl/auth/driver-email-otp/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim()}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to send verification code');
    }
  }

  /// Verifies the driver's email OTP during registration.
  Future<void> verifyDriverEmailOTP(String email, String otp) async {
    final response = await http.post(
      Uri.parse('$_mainUrl/auth/driver-email-otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'otp': otp.trim()}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Invalid or expired verification code');
    }
  }

  /// Encrypts driver password before sending for registration.
  Future<void> registerDriver(Map<String, dynamic> data) async {
    final publicKey = await _fetchPublicKey();
    if (data.containsKey('password')) {
      data['password'] = _encryptPassword(data['password'] as String, publicKey);
    }

    final response = await http.post(
      Uri.parse('$_mainUrl/auth/register-driver'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      if (!(response.headers['content-type']?.contains('application/json') ?? false)) {
        throw Exception('Server Error: Invalid response (${response.statusCode})');
      }
      try {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Driver Registration Failed');
      } on FormatException {
        throw Exception('Server Error: Invalid JSON (${response.statusCode})');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMMON UPDATE FUNCTIONS (unchanged — use main backend directly)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> verifyDriverLicense(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$_mainUrl/auth/verify-driver'),
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Verification Failed');
    }
  }

  Future<void> updateProfileImage(String userId, String base64Image) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$_mainUrl/auth/update-profile-image'),
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'id': userId, 'profileImage': base64Image}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update image: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, String> data) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$_mainUrl/auth/update-profile'),
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    final body = jsonDecode(response.body);
    throw Exception(body['message'] ?? 'Failed to update profile');
  }
}
