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
import 'secure_storage_service.dart';

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

      // Also store user info for quick access without an API call
      await _storage.write(key: PrefKeys.userName, value: user['name'] as String? ?? '');
      await _storage.write(key: PrefKeys.userRole, value: user['role'] as String? ?? '');

      if ((user['role'] as String?) == UserRoles.driver && user['licenseNumber'] != null) {
        await _storage.write(key: PrefKeys.licenseNum, value: user['licenseNumber'] as String);
      }

      debugPrint('[AuthService] Login successful — role: ${user["role"]}');

      // Return the user map — login_screen.dart reads userData['role'] to navigate
      return user;
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Login Failed');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────────────────────────────────

  /// Revokes the session on the server then clears all local storage.
  Future<void> logout() async {
    debugPrint('[AuthService] logout() called');

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
        debugPrint('[AuthService] Warning: could not revoke session on server: $e');
      }
    }

    // Always clear local storage regardless of server response
    await SecureStorageService().clearAllAuth();
    _cachedPublicKey = null;
    debugPrint('[AuthService] All session data cleared');
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

  Future<void> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$_mainUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to send OTP');
    }
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
        final List<dynamic> data = jsonDecode(response.body);
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
