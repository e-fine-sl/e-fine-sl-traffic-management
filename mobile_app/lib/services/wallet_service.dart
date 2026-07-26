// lib/services/wallet_service.dart
// Digital Wallet API service — connects to the separate mock_data_loader backend.
// This service NEVER calls backend_api.
// ─────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/wallet_model.dart';
import '../config/app_constants.dart';
import 'auth_service.dart';
import 'secure_storage_service.dart';

class WalletService {
  static const String _baseUrl = ApiConstants.walletUrl;


  static const Duration _timeout = Duration(seconds: 15);

  // ── GET /api/wallet ───────────────────────────────
  /// Gets wallet from cache if available, otherwise fetches from API.
  Future<WalletModel> getWallet({bool forceRefresh = false}) async {
    final storage = SecureStorageService();
    
    if (!forceRefresh) {
      final cached = await storage.getCachedWallet();
      if (cached != null) {
        try {
          return WalletModel.fromJson(cached);
        } catch (e) {
          // If parsing fails, fall through to fetch fresh data
        }
      }
    }

    return loadMyWallet();
  }

  /// Automatically load the digital wallet for the logged-in user from API.
  Future<WalletModel> loadMyWallet() async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();
      
      if (token == null) {
        throw const WalletException('Session expired. Please log in again.', statusCode: 401);
      }

      final response = await http
          .get(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final walletMap = data['wallet'] as Map<String, dynamic>;
        await SecureStorageService().cacheWallet(walletMap);
        return WalletModel.fromJson(walletMap);
      } else if (response.statusCode == 404) {
        throw WalletException(
          'No wallet found. Check your NIC and License Number.',
          statusCode: 404,
        );
      } else {
        throw WalletException(
          data['message'] as String? ?? 'Server error. Please try again.',
          statusCode: response.statusCode,
        );
      }
    } on WalletException {
      rethrow;
    } catch (e) {
      throw WalletException('Server error. Please try again later.');
    }
  }

  // ── GET /api/wallet/vehicle/:registrationNo?nic= ──────────
  /// Get all documents for a single vehicle.
  Future<VehicleModel> getVehicleDocuments(
    String registrationNo,
    String nic,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/vehicle/${Uri.encodeComponent(registrationNo)}')
          .replace(queryParameters: {'nic': nic.trim().toUpperCase()});

      final response = await http.get(uri).timeout(_timeout);
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return VehicleModel.fromJson(data['vehicle'] as Map<String, dynamic>);
      } else if (response.statusCode == 403) {
        throw WalletException(
          'This vehicle does not belong to your NIC.',
          statusCode: 403,
        );
      } else if (response.statusCode == 404) {
        throw WalletException(
          'Vehicle not found.',
          statusCode: 404,
        );
      } else {
        throw WalletException('Server error. Please try again later.');
      }
    } on WalletException {
      rethrow;
    } catch (e) {
      throw WalletException('Server error. Please try again later.');
    }
  }

  // ── GET /api/wallet/check/:nic ────────────────────────────
  /// Quick summary check — use for dashboard badge/alert.
  Future<WalletSummaryModel> checkValidity(String nic) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/check/${Uri.encodeComponent(nic.trim().toUpperCase())}'))
          .timeout(_timeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return WalletSummaryModel.fromJson(data['summary'] as Map<String, dynamic>);
      } else if (response.statusCode == 404) {
        throw WalletException('No wallet found for this NIC.', statusCode: 404);
      } else {
        throw WalletException('Server error. Please try again later.');
      }
    } on WalletException {
      rethrow;
    } catch (e) {
      throw WalletException('Server error. Please try again later.');
    }
  }

  // ── POST /api/wallet/refresh ──────────────────────────────
  /// Force a fresh wallet fetch (cache-busting).
  Future<WalletModel> refreshWallet() async {
    return loadMyWallet();
  }
}

// ─────────────────────────────────────────────────────────
// Custom exception for wallet API errors
// ─────────────────────────────────────────────────────────
class WalletException implements Exception {
  final String message;
  final int? statusCode;

  const WalletException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
