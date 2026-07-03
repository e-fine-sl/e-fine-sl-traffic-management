import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http_pkg;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
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
    List<File>? images,
  }) async {
    debugPrint('\n${'═' * 55}');
    debugPrint('$_tag 🚨 REPORT ACCIDENT: $accidentType');
    debugPrint('$_tag Location: $lat, $lng');
    if (images != null) debugPrint('$_tag Images: ${images.length}');
    debugPrint('═' * 55);

    try {
      final token = await _authService.getToken();
      
      final request = http_pkg.MultipartRequest('POST', Uri.parse(ApiConstants.accidentReportUrl));
      
      // Add Headers
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add Fields
      request.fields['licenseNumber'] = licenseNumber;
      request.fields['lat'] = lat.toString();
      request.fields['lng'] = lng.toString();
      request.fields['accidentType'] = accidentType;
      if (description != null && description.isNotEmpty) {
        request.fields['description'] = description;
      }

      // Add Files
      if (images != null && images.isNotEmpty) {
        for (var image in images) {
          final stream = http_pkg.ByteStream(image.openRead());
          final length = await image.length();
          final ext = p.extension(image.path).replaceAll('.', '').toLowerCase();
          final String mimeType = ext == 'png' ? 'png' : (ext == 'webp' ? 'webp' : 'jpeg');

          final multipartFile = http_pkg.MultipartFile(
            'images',
            stream,
            length,
            filename: p.basename(image.path),
            contentType: MediaType('image', mimeType),
          );
          request.files.add(multipartFile);
        }
      }

      // Send using our logger client to keep consistent logging
      final streamedResponse = await http.httpLogger.send(request);
      final response = await http_pkg.Response.fromStream(streamedResponse);

      debugPrint('$_tag HTTP Status: ${response.statusCode}');
      debugPrint('$_tag Response: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'officersNotified': data['debug']?['officersNotified'] ?? 0,
          'province': data['debug']?['province'] ?? '',
          'district': data['debug']?['district'] ?? '',
          'policeDivision': data['debug']?['policeDivision'] ?? '',
          'reportId': data['reportId'] ?? '',
          'message': data['message'] ?? 'Alert sent'
        };
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Failed to send alert (${response.statusCode})'};
      }
    } catch (e) {
      debugPrint('$_tag ❌ EXCEPTION: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
