import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_logger.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import 'auth_service.dart';

class FineService {
  // Your IP address (change here if it changes)
  static const String baseUrl = ApiConstants.baseUrl;
  final _storage = const FlutterSecureStorage(); // For licenseNum & badgeNumber only
  final _authService = AuthService(); // For token management

  // ----------------------------------------------------------------
  // 1. Offenses List (No changes)
  // ----------------------------------------------------------------
  Future<List<dynamic>> getOffenses() async {
    try {
      String? token = await _authService.getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/fines/offenses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load offenses');
      }
    } catch (e) {
      throw Exception('Error fetching offenses: $e');
    }
  }

  // ----------------------------------------------------------------
  // 2. Issue Fine (No changes)
  // ----------------------------------------------------------------
  Future<bool> issueFine(Map<String, dynamic> fineData) async {
    try {
      String? token = await _authService.getToken();
      if (token == null) {
        throw Exception("Token missing. Please Logout & Login.");
      }

      final response = await http.post(
        Uri.parse('$baseUrl/fines/issue'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(fineData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        final msg = jsonDecode(response.body)['message'] ?? response.body;
        throw Exception("Server Error: $msg");
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // ----------------------------------------------------------------
  // 3. Get History (Correct endpoint)
  // ----------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getOfficerFineHistory() async {
    try {
      String? token = await _authService.getToken();
      String? badge = await _storage.read(key: PrefKeys.badgeNumber); // Officer ID

      if (token == null || badge == null) {
        throw Exception("Auth data missing. Logout and Login.");
      }

      // --- Corrected URL ---
      // The route file you sent has '/history', so this must be '/fines/history'.
      // Since the Database parameter name is 'policeOfficerId', we pass it as a Query Parameter.

      final uri = Uri.parse('$baseUrl/fines/history').replace(queryParameters: {
        'policeOfficerId': badge,
      });

      // print("Calling URL: $uri"); // Helpful for debugging

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // ----------------------------------------------------------------
  // 4. Get Pending Fines (Driver)
  // ----------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getDriverPendingFines() async {
    try {
      String? token = await _authService.getToken();
      String? licenseNumber = await _storage.read(key: PrefKeys.licenseNum);
      
      if (token == null || licenseNumber == null) return [];

      final uri = Uri.parse('$baseUrl/fines/pending').replace(queryParameters: {
        'licenseNumber': licenseNumber,
      });

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching pending fines: $e");
      return [];
    }
  }

  // Internal helper for fetching fines with any endpoint + query params
  Future<List<Map<String, dynamic>>> _fetchFinesInternal({
    required String endpoint,
    required String token,
    required String queryKey,
    required String queryValue,
  }) async {
    final uri = Uri.parse('$baseUrl/fines/$endpoint').replace(queryParameters: {
      queryKey: queryValue,
    });

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  // Mark Fine as Paid
  Future<bool> payFine(String fineId, String paymentId) async {
    final url = Uri.parse('$baseUrl/fines/$fineId/pay');
    try {
      String? token = await _authService.getToken();
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'paymentId': paymentId}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint("PayFine Error: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("PayFine Exception: $e");
      return false;
    }
  }

  // ----------------------------------------------------------------
  // 6. Caching Helpers
  // ----------------------------------------------------------------
  
  Future<void> _cachePaidFines(List<Map<String, dynamic>> fines) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefKeys.historyCache, jsonEncode(fines));
    } catch (e) {
      debugPrint("Error caching history: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getPaidFinesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(PrefKeys.historyCache);
      if (cached != null) {
        final decoded = jsonDecode(cached) as List<dynamic>;
        return List<Map<String, dynamic>>.from(decoded);
      }
    } catch (e) {
      debugPrint("Error reading from cache: $e");
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getDriverPaidFines() async {
    try {
      String? token = await _authService.getToken();
      String? licenseNumber = await _storage.read(key: PrefKeys.licenseNum);
      
      if (token == null || licenseNumber == null) return [];

      // Fetch from network
      List<Map<String, dynamic>> results = await _fetchFinesInternal(
        endpoint: 'driver-history',
        token: token,
        queryKey: 'licenseNumber',
        queryValue: licenseNumber,
      );

      // Fallback to 'licenseNo'
      if (results.isEmpty) {
        results = await _fetchFinesInternal(
          endpoint: 'driver-history',
          token: token,
          queryKey: 'licenseNo',
          queryValue: licenseNumber,
        );
      }

      // If we got results, update cache
      if (results.isNotEmpty) {
        await _cachePaidFines(results);
      }

      return results;
    } catch (e) {
      debugPrint("Error fetching history: $e");
      return [];
    }
  }

  // ----------------------------------------------------------------
  // 5. Get Driver Status (Demerit Points)
  // ----------------------------------------------------------------
  Future<Map<String, dynamic>> getDriverStatus() async {
    try {
      String? token = await _authService.getToken();
      String? licenseNumber = await _storage.read(key: PrefKeys.licenseNum);

      if (token == null || licenseNumber == null) {
        throw Exception("Auth data missing.");
      }

      final uri = Uri.parse('$baseUrl/drivers/$licenseNumber/status');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching driver status: $e');
    }
  }

  // Fetch driver status by specific license number (used by Police Officers)
  Future<Map<String, dynamic>?> getDriverStatusByLicense(String licenseNumber) async {
    try {
      String? token = await _authService.getToken();
      if (token == null || licenseNumber.isEmpty) return null;

      final uri = Uri.parse('$baseUrl/drivers/$licenseNumber/status');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching driver status by license: $e');
      return null;
    }
  }
}
