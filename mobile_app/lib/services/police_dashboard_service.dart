import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_logger.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_constants.dart';
import '../models/police_dashboard_model.dart';
import 'auth_service.dart';

class PoliceDashboardService {

  static const String baseUrl = ApiConstants.baseUrl;
  final _storage = const FlutterSecureStorage();
  final _authService = AuthService();

  Future<Map<String, dynamic>?> getPoliceDashboardData() async {
    final creds = <String, String>{};
    if (await _getTokenAndBadge(creds) == null) return null;

    try {
      final uri = Uri.parse('$baseUrl/police/dashboard');
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${creds['token']!}',
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return responseData['data'];
        }
      }
    } catch (e) {
      debugPrint("Error fetching dashboard data: $e");
    }
    return null;
  }

  Future<String?> _getTokenAndBadge(Map<String, String> creds) async {
    String? token = await _authService.getToken();
    String? badge = await _storage.read(key: PrefKeys.badgeNumber);
    if (token == null || badge == null) return null;
    creds['token'] = token;
    creds['badge'] = badge;
    return token;
  }

  Future<DailyStatsModel?> getDailyStats() async {
    final creds = <String, String>{};
    if (await _getTokenAndBadge(creds) == null) return null;

    try {
      final uri = Uri.parse('$baseUrl/police/daily-stats');
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${creds['token']!}',
      });

      if (response.statusCode == 200) {
        return DailyStatsModel.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error fetching daily stats: $e");
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getRecentFines() async {
    final creds = <String, String>{};
    if (await _getTokenAndBadge(creds) == null) return [];

    try {
      final uri = Uri.parse('$baseUrl/police/recent-fines');
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${creds['token']!}',
      });

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error fetching recent fines: $e");
    }
    return [];
  }

  Future<List<HqAlertModel>> getHqAlerts() async {
    final creds = <String, String>{};
    if (await _getTokenAndBadge(creds) == null) return [];

    try {
      final uri = Uri.parse('$baseUrl/police/hq-alerts');
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${creds['token']!}',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => HqAlertModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching HQ alerts: $e");
    }
    return [];
  }

  Future<bool> registerSosAlert(String location, String officerName) async {
    final creds = <String, String>{};
    if (await _getTokenAndBadge(creds) == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/police/sos'),
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
      
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint("Error registering SOS: $e");
      return false;
    }
  }
}
