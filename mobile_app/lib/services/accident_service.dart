import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'api_logger.dart' as http;
import 'auth_service.dart';
import '../config/app_constants.dart';

class AccidentService {
  static const String _tag = '[AccidentService]';
  final _authService = AuthService();

  Future<Position> getCurrentLocation() async {
    debugPrint('\n$_tag STEP 1: Checking location permission...');
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      debugPrint('$_tag    Permission denied — requesting...');
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permission permanently denied. Please enable it in Settings.';
    }

    if (permission == LocationPermission.denied) {
      throw 'Location permission is required to send Accident Alert.';
    }

    debugPrint('$_tag STEP 2: Checking if location service is enabled...');
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'GPS is disabled. Please turn on Location Services.';
    }

    debugPrint('$_tag STEP 3: Fetching high-accuracy GPS position...');
    try {
      final position = await Geolocator.getCurrentPosition(
        // ignore: deprecated_member_use
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      return position;
    } catch (e) {
      throw 'Failed to get GPS location: $e';
    }
  }

  Future<Map<String, dynamic>> reportAccident({
    required String licenseNumber,
    required double lat,
    required double lng,
    required String accidentType,
    String? description,
  }) async {
    debugPrint('\n${'═' * 55}');
    debugPrint('$_tag 🚨 REPORT ACCIDENT: $accidentType');
    debugPrint('$_tag Location: $lat, $lng');
    debugPrint('═' * 55);

    final body = {
      'licenseNumber': licenseNumber,
      'lat': lat,
      'lng': lng,
      'accidentType': accidentType,
      if (description != null && description.isNotEmpty) 'description': description,
    };

    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse(ApiConstants.accidentReportUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      debugPrint('$_tag HTTP Status: ${response.statusCode}');
      debugPrint('$_tag Response: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'officersNotified': data['debug']['officersNotified'] ?? 0,
          'province': data['debug']['province'] ?? '',
          'district': data['debug']['district'] ?? '',
          'policeDivision': data['debug']['policeDivision'] ?? '',
          'reportId': data['reportId'] ?? '',
          'message': data['message'] ?? 'Alert sent'
        };
      } else if (response.statusCode == 404) {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Driver not found'};
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Invalid request'};
      } else {
        return {'success': false, 'message': 'Server error (${response.statusCode})'};
      }
    } catch (e) {
      debugPrint('$_tag ❌ EXCEPTION: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
