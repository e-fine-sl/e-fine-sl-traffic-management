import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_constants.dart';

class DmtService {
  static const String _tag = '[DmtService]';

  Future<List<dynamic>> fetchAllowedVehicles(String nic, String licenseNumber) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.dmtVerifyUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'nic': nic,
          'licenseNumber': licenseNumber,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data']['vehicleClasses'] ?? [];
        }
      }
      return [];
    } catch (e) {
      // Error handling can just return empty and log
      debugPrint('$_tag Error fetching allowed vehicles from DMT Server: $e');
      return [];
    }
  }
}
