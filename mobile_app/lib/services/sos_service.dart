// ─────────────────────────────────────────────────────────────────────────────
// lib/services/sos_service.dart
// e-Fine SL — SOS Emergency Alert Service
//
// RESPONSIBILITIES:
//  1. Request location permission + fetch precise GPS fix
//  2. POST to /api/sos with badge, GPS coordinates, emergencyType
//  3. Register officer FCM token + location on login → PUT /api/sos/update-location
//
// DEBUG: Every step prints a labeled debugPrint so you can follow in the
//         Flutter console during the university demo.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_logger.dart' as http;
import 'auth_service.dart';
import 'notification_service.dart';
import '../config/app_constants.dart';
import '../screens/police/accident_alert_screen.dart';
import 'package:mobile_app/main.dart' show navigatorKey;

class SosService {
  static const String _tag = '[SosService]';
  static const String _baseUrl = ApiConstants.baseUrl;

  final _storage = const FlutterSecureStorage();
  final _authService = AuthService();

  // ──────────────────────────────────────────────────────────────────────────
  // PUBLIC: triggerSOS()
  // Called when an SOS button is tapped.
  // Returns a result map with keys: success (bool), message (String)
  // ──────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> triggerSOS(String emergencyType) async {
    debugPrint('\n${'═' * 55}');
    debugPrint('$_tag 🚨 SOS TRIGGERED: $emergencyType');
    debugPrint('$_tag Timestamp: ${DateTime.now().toIso8601String()}');
    debugPrint('═' * 55);

    // ── STEP 1: Get badge number ──────────────────────────────────────────
    debugPrint('$_tag STEP 1: Reading badgeNumber from secure storage...');
    final badgeNumber = await _storage.read(key: 'badgeNumber');
    debugPrint('$_tag    badgeNumber = "$badgeNumber"');

    if (badgeNumber == null || badgeNumber.isEmpty) {
      debugPrint('$_tag ❌ STEP 1 FAILED: badgeNumber not found in storage.');
      return {'success': false, 'message': 'Officer badge number not found. Please log in again.'};
    }
    debugPrint('$_tag ✅ STEP 1 OK');

    // ── STEP 2: Request location permission ──────────────────────────────
    debugPrint('\n$_tag STEP 2: Checking location permission...');
    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint('$_tag    Current permission: $permission');

    if (permission == LocationPermission.denied) {
      debugPrint('$_tag    Permission denied — requesting...');
      permission = await Geolocator.requestPermission();
      debugPrint('$_tag    After request: $permission');
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('$_tag ❌ STEP 2 FAILED: Location permission permanently denied.');
      return {'success': false, 'message': 'Location permission permanently denied. Please enable it in Settings.'};
    }

    if (permission == LocationPermission.denied) {
      debugPrint('$_tag ❌ STEP 2 FAILED: Location permission denied by user.');
      return {'success': false, 'message': 'Location permission is required to send SOS.'};
    }
    debugPrint('$_tag ✅ STEP 2 OK: Permission = $permission');

    // ── STEP 3: Check if location service is enabled ─────────────────────
    debugPrint('\n$_tag STEP 3: Checking if location service is enabled...');
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('$_tag    Location service enabled: $serviceEnabled');

    if (!serviceEnabled) {
      debugPrint('$_tag ❌ STEP 3 FAILED: Location service disabled.');
      return {'success': false, 'message': 'GPS is disabled. Please turn on Location Services.'};
    }
    debugPrint('$_tag ✅ STEP 3 OK');

    // ── STEP 4: Get precise GPS position ─────────────────────────────────
    debugPrint('\n$_tag STEP 4: Fetching high-accuracy GPS position...');
    debugPrint('$_tag    (This can take 3-10 seconds on first request)');

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        // ignore: deprecated_member_use
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      debugPrint('$_tag ✅ STEP 4 OK: lat=${position.latitude}, lng=${position.longitude}');
      debugPrint('$_tag    accuracy=${position.accuracy}m, altitude=${position.altitude}m');
    } catch (e) {
      debugPrint('$_tag ❌ STEP 4 FAILED: $e');
      return {'success': false, 'message': 'Failed to get GPS location: $e'};
    }

    // ── STEP 5: Build & POST /api/sos ─────────────────────────────────────
    debugPrint('\n$_tag STEP 5: Sending SOS to backend...');
    final body = {
      'badgeNumber': badgeNumber,
      'lat': position.latitude,
      'lng': position.longitude,
      'emergencyType': emergencyType,
    };
    debugPrint('$_tag    POST $_baseUrl/sos');
    debugPrint('$_tag    Body: ${jsonEncode(body)}');

    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/sos'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      debugPrint('$_tag    HTTP Status: ${response.statusCode}');
      debugPrint('$_tag    Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final notified = (data['debug'] as Map?)?['fcmSent'] ?? 0;
        debugPrint('$_tag ✅ STEP 5 OK: SOS sent! $notified officer(s) notified.');
        return {
          'success': true,
          'message': 'SOS Alert Sent! $notified officer(s) notified.',
          'data': data,
        };
      } else {
        final data = jsonDecode(response.body);
        debugPrint('$_tag ❌ STEP 5 FAILED: ${response.statusCode} — ${data['message']}');
        return {'success': false, 'message': data['message'] ?? 'SOS failed (${response.statusCode})'};
      }
    } catch (e) {
      debugPrint('$_tag ❌ STEP 5 EXCEPTION: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PUBLIC: registerPresence()
  // Call this after a successful login to store FCM token + location in DB.
  // This is what populates the data needed for $near queries to work.
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> registerPresence(String badgeNumber) async {
    debugPrint('\n$_tag 📍 registerPresence() called for badge: $badgeNumber');

    // ── Get FCM Token ──────────────────────────────────────────────────────
    debugPrint('$_tag STEP A: Fetching FCM token from Firebase...');
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint('$_tag ✅ FCM Token obtained: ...${fcmToken?.substring(fcmToken.length - 15)}');
    } catch (e) {
      debugPrint('$_tag ❌ Failed to get FCM token: $e');
      debugPrint('$_tag    → Make sure google-services.json is in android/app/ and Firebase is initialized in main.dart');
      return; // Non-fatal — don't crash if FCM fails
    }

    if (fcmToken == null || fcmToken.isEmpty) {
      debugPrint('$_tag ❌ FCM token is null — cannot register presence.');
      return;
    }

    // ── Get GPS Location (best-effort, non-blocking) ───────────────────────
    debugPrint('$_tag STEP B: Getting location for presence registration...');
    double? lat;
    double? lng;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          // ignore: deprecated_member_use
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
        lat = pos.latitude;
        lng = pos.longitude;
        debugPrint('$_tag ✅ Location for presence: lat=$lat, lng=$lng');
      } else {
        debugPrint('$_tag ⚠️ Location permission not granted yet — skipping location in presence update.');
      }
    } catch (e) {
      debugPrint('$_tag ⚠️ Could not get location for presence (non-fatal): $e');
    }

    // ── PUT /api/sos/update-location ───────────────────────────────────────
    debugPrint('$_tag STEP C: Sending presence to backend...');
    final body = <String, dynamic>{
      'badgeNumber': badgeNumber,
      'fcmToken': fcmToken,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
    debugPrint('$_tag    PUT $_baseUrl/sos/update-location');
    debugPrint('$_tag    Body: ${jsonEncode(body)}');

    try {
      final token = await _authService.getToken();
      final response = await http.put(
        Uri.parse('$_baseUrl/sos/update-location'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      debugPrint('$_tag    HTTP Status: ${response.statusCode}');
      debugPrint('$_tag    Response: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('$_tag ✅ Presence registered successfully!');
      } else {
        debugPrint('$_tag ❌ Presence registration failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('$_tag ❌ Presence registration exception (non-fatal): $e');
    }
  }

  /// Signals logout to the backend — records logout time + location.
  /// Call this BEFORE clearing storage in auth_service.dart logout().
  Future<void> signalLogout(String badgeNumber) async {
    debugPrint('$_tag [Logout] signalLogout() called for: $badgeNumber');

    double? lat;
    double? lng;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          // ignore: deprecated_member_use
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 6),
        );
        lat = pos.latitude;
        lng = pos.longitude;
        debugPrint('$_tag ✅ Logout location: lat=$lat, lng=$lng');
      }
    } catch (e) {
      debugPrint('$_tag ⚠️ Could not get logout location (non-fatal): $e');
    }

    final body = <String, dynamic>{
      'badgeNumber': badgeNumber,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };

    try {
      final token = await _authService.getToken();
      final response = await http.put(
        Uri.parse('$_baseUrl/officer/logout'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        debugPrint('$_tag ✅ Logout signal sent to backend successfully');
      } else {
        debugPrint('$_tag ⚠️ Logout signal failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('$_tag ⚠️ Logout signal exception (non-fatal): $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PUBLIC: setupFCMListeners()
  // Call once from main.dart after Firebase.initializeApp().
  // Handles incoming SOS push notifications for the RECEIVING officers.
  // ──────────────────────────────────────────────────────────────────────────
  static void setupFCMListeners() {
    debugPrint('$_tag 🔔 Setting up FCM listeners...');

    // Request notification permission (Android 13+ / iOS)
    FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    ).then((settings) {
      debugPrint('$_tag    Notification permission status: ${settings.authorizationStatus}');
    });

    // Foreground messages (app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('\n$_tag [FCM] FOREGROUND MESSAGE RECEIVED');
      debugPrint('$_tag    Title: ${message.notification?.title}');
      debugPrint('$_tag    Body:  ${message.notification?.body}');
      debugPrint('$_tag    Data:  ${message.data}');
      
      // ── Handle ACCIDENT_ALERT ────────────────────────────────
      final type = message.data['type'] as String? ?? '';
      if (type == 'ACCIDENT_ALERT') {
        debugPrint('$_tag [Accident] ACCIDENT_ALERT received — showing local notification');
        
        // Show local high-priority notification
        NotificationService().showAccidentNotification(
          title: message.notification?.title ?? 'Accident Alert',
          body: message.notification?.body ?? 'An accident has been reported nearby',
          payload: jsonEncode(message.data),
        );

        // Navigate to AccidentAlertScreen if app is open
        final data = message.data;
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => AccidentAlertScreen(
              accidentType: data['accidentType'] ?? 'Unknown',
              driverName: data['driverName'] ?? '',
              licenseNumber: data['licenseNumber'] ?? '',
              driverPhone: data['driverPhone'] ?? '',
              description: data['description'] ?? '',
              lat: double.tryParse(data['lat'] ?? '0') ?? 0.0,
              lng: double.tryParse(data['lng'] ?? '0') ?? 0.0,
              province: data['province'] ?? '',
              district: data['district'] ?? '',
              policeDivision: data['policeDivision'] ?? '',
              reportedAt: data['reportedAt'] ?? '',
              reportId: data['reportId'] ?? '',
            ),
          ),
        );
      }
    });

    // Background tap (app was in background, user tapped the notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('$_tag 📲 User TAPPED background notification:');
      debugPrint('$_tag    Data: ${message.data}');
      
      final type = message.data['type'] as String? ?? '';
      if (type == 'ACCIDENT_ALERT') {
        final data = message.data;
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => AccidentAlertScreen(
              accidentType: data['accidentType'] ?? 'Unknown',
              driverName: data['driverName'] ?? '',
              licenseNumber: data['licenseNumber'] ?? '',
              driverPhone: data['driverPhone'] ?? '',
              description: data['description'] ?? '',
              lat: double.tryParse(data['lat'] ?? '0') ?? 0.0,
              lng: double.tryParse(data['lng'] ?? '0') ?? 0.0,
              province: data['province'] ?? '',
              district: data['district'] ?? '',
              policeDivision: data['policeDivision'] ?? '',
              reportedAt: data['reportedAt'] ?? '',
              reportId: data['reportId'] ?? '',
            ),
          ),
        );
      }
    });

    debugPrint('$_tag ✅ FCM listeners registered.');
  }
}
