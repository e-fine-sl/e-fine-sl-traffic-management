import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:mobile_app/services/auth_service.dart';
import 'package:mobile_app/services/secure_storage_service.dart';
import 'package:qr_flutter/qr_flutter.dart'; 
import 'dart:convert'; // To encode JSON
import '../../config/app_constants.dart';

import '../../services/wallet_service.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfileScreen({super.key, required this.userData});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _tag = '[ProfileScreen]';

  late List<dynamic> _vehicleClasses;
  bool _isLoadingVehicles = false;

  // Mutable local copy of profile data — updated on pull-to-refresh
  late Map<String, dynamic> _userData;

  late String _addressLine1;
  late String _addressLine2;
  late String _city;
  late String _postalCode;

  @override
  void initState() {
    super.initState();
    debugPrint('$_tag initState() — loading from passed userData.');

    _userData = Map<String, dynamic>.from(widget.userData);
    _vehicleClasses = _userData['vehicleClasses'] ?? [];

    // Migration fallback for old data: use 'address' if Line 1 is empty
    _addressLine1 = _userData['addressLine1'] ?? _userData['address'] ?? '';
    _addressLine2 = _userData['addressLine2'] ?? '';
    _city = _userData['city'] ?? '';
    _postalCode = _userData['postalCode'] ?? '';

    // If vehicle classes are empty upon navigating to the driver profile, make an API call to fetch them.
    if (_vehicleClasses.isEmpty) {
      _fetchAllowedVehicles();
    }
  }

  // ── PULL-TO-REFRESH ────────────────────────────────────────────────────────

  Future<void> _handleRefresh() async {
    debugPrint('$_tag Pull-to-refresh triggered.');
    try {
      debugPrint('$_tag Fetching fresh profile from API...');
      final freshData = await AuthService().getUserProfile();

      debugPrint('$_tag Profile refreshed. Updating cache...');
      await SecureStorageService().cacheProfile(freshData);

      if (!mounted) return;

      setState(() {
        _userData   = Map<String, dynamic>.from(freshData);
        _vehicleClasses = _userData['vehicleClasses'] ?? [];
        _addressLine1   = _userData['addressLine1'] ?? _userData['address'] ?? '';
        _addressLine2   = _userData['addressLine2'] ?? '';
        _city           = _userData['city'] ?? '';
        _postalCode     = _userData['postalCode'] ?? '';
      });

      debugPrint('$_tag UI updated with fresh profile data.');
    } catch (e) {
      debugPrint('$_tag Error during refresh: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('refresh_failed'.tr()),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  // ── VEHICLE CLASSES ────────────────────────────────────────────────────────

  Future<void> _fetchAllowedVehicles() async {
    debugPrint('$_tag _fetchAllowedVehicles() called.');
    final nic     = _userData['nic'];
    final license = _userData['licenseNumber'];

    if (nic == null || license == null) {
      debugPrint('$_tag _fetchAllowedVehicles() — NIC or licenseNumber is null, skipping.');
      return;
    }

    setState(() => _isLoadingVehicles = true);

    try {
      final wallet = await WalletService().verifyAndLoadWallet(nic, license);
      if (wallet.drivingLicense != null) {
        setState(() {
          _vehicleClasses = wallet.drivingLicense!.vehicleClasses;
        });
        debugPrint('$_tag Vehicle classes loaded: ${_vehicleClasses.length} class(es).');
      } else {
        debugPrint('$_tag _fetchAllowedVehicles() — drivingLicense is null in wallet response.');
      }
    } catch (e) {
      debugPrint('$_tag Error fetching vehicle classes: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingVehicles = false);
      }
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    bool isVerified  = _userData['isVerified'] ?? false;
    String issueDate  = _userData['licenseIssueDate'] ?? "N/A";
    String expiryDate = _userData['licenseExpiryDate'] ?? "N/A";

    // --- STATUS CHECK ---
    String status   = _userData['licenseStatus'] ?? "ACTIVE";
    bool isActive   = status == "ACTIVE";

    return Scaffold(
      appBar: AppBar(
        title: Text("my_profile".tr()),
        backgroundColor: AppColors.primaryGreenDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // --- QR CODE BUTTON ---
          IconButton(
            icon: const Icon(Icons.qr_code_2, size: 30),
            onPressed: () {
              if (_userData['name'] == null || _userData['phone'] == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Some data missing. Try refreshing profile."),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
              _showMyQRCode(context);
            },
          )
        ],
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.primaryGreenDark,
        child: SingleChildScrollView(
          // Ensure scrollable even when content is short (needed for RefreshIndicator)
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // 1. PROFILE HEADER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 30),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: _getProfileImage(_userData['profileImage']),
                            backgroundColor: Colors.white,
                          ),
                        ),
                        if (isVerified)
                          const CircleAvatar(
                            radius: 15,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.verified, color: Colors.blue, size: 20),
                          )
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _userData['name'],
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      _userData['email'],
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(height: 10),

                    // Status Badge (Active/Suspended)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.white : AppColors.errorRed,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive ? "active_license".tr() : "suspended_license".tr(),
                        style: TextStyle(
                          color: isActive ? AppColors.successGreen : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. PERSONAL DETAILS CARD
              _buildSectionTitle("personal_details".tr()),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: const EdgeInsets.all(20),
                decoration: _boxDecoration(context),
                child: Column(
                  children: [
                    _buildProfileRow(context, Icons.credit_card, "nic_label".tr(), _userData['nic']),
                    const Divider(),
                    _buildProfileRow(context, Icons.phone, "mobile_label".tr(), _userData['phone']),
                    const Divider(),
                    _buildProfileRow(
                      context,
                      Icons.warning_amber,
                      "demerits_label".tr(),
                      "points_display".tr(args: [_userData['demeritPoints'].toString()]),
                      isHighlight: true,
                    ),
                  ],
                ),
              ),

              // 3. LICENSE DETAILS CARD
              if (isVerified) ...[
                _buildSectionTitle("digital_license_info".tr()),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  padding: const EdgeInsets.all(20),
                  decoration: _boxDecoration(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("license_label".tr(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 5),
                              Text(
                                _userData['licenseNumber'],
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ],
                          ),
                          // Status Icon
                          Icon(
                            isActive ? Icons.check_circle : Icons.block,
                            color: isActive ? AppColors.successGreen : AppColors.errorRed,
                            size: 30,
                          ),
                        ],
                      ),
                      const Divider(height: 30),

                      // Dates
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDateColumn(context, "issue_date".tr(), issueDate),
                          _buildDateColumn(context, "expiry_date".tr(), expiryDate, isExpiry: true),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSmallImageCard(context, "front_view".tr(), _userData['licenseFrontImage']),
                          _buildSmallImageCard(context, "back_view".tr(), _userData['licenseBackImage']),
                        ],
                      ),
                      const Divider(height: 30),

                      // Classes
                      Text("allowed_vehicles".tr(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 10),

                      _isLoadingVehicles
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(10.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _vehicleClasses.isEmpty
                              ? Text("no_classes".tr(), style: const TextStyle(color: AppColors.errorRed))
                              : Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: _vehicleClasses.map((item) {
                                    if (item is Map) {
                                      return _buildClassChip(
                                        item['category']?.toString() ?? '',
                                        item['issueDate']?.toString() ?? '',
                                        item['expiryDate']?.toString() ?? '',
                                      );
                                    }
                                    return _buildClassChip(item.toString(), '', '');
                                  }).toList(),
                                ),

                      // Address Section
                      const Divider(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("residential_address".tr(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                            onPressed: _showEditAddressDialog,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_addressLine1.isNotEmpty)
                            Text(_addressLine1, style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (_addressLine2.isNotEmpty)
                            Text(_addressLine2, style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (_city.isNotEmpty)
                            Text(_city, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            "${"postal".tr()}: $_postalCode",
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ── QR CODE DISPLAY ────────────────────────────────────────────────────────

  void _showMyQRCode(BuildContext context) {
    debugPrint('$_tag _showMyQRCode() called.');
    Map<String, dynamic> qrData = {
      "name":    _userData['name'],
      "nic":     _userData['nic'],
      "license": _userData['licenseNumber'] ?? "N/A",
      "phone":   _userData['phone'],
      "vehicleNumber": _userData['vehicleNumber'] ?? "N/A",
      "type":    "driver_identity",
    };

    String qrString = jsonEncode(qrData);
    debugPrint('$_tag QR data prepared: $qrString');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "My Digital Identity",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              width: 220,
              child: QrImageView(
                data: qrString,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Show this to the Traffic Police Officer to fetch your details.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // ── EDIT ADDRESS DIALOG ────────────────────────────────────────────────────

  void _showEditAddressDialog() {
    debugPrint('$_tag _showEditAddressDialog() opened.');
    final line1Controller   = TextEditingController(text: _addressLine1);
    final line2Controller   = TextEditingController(text: _addressLine2);
    final cityController    = TextEditingController(text: _city);
    final postalController  = TextEditingController(text: _postalCode);
    final vehicleController = TextEditingController(text: _userData['vehicleNumber'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit Profile Details"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: line1Controller,
                decoration: InputDecoration(labelText: "${"address_label".tr()} 1"),
              ),
              TextField(
                controller: line2Controller,
                decoration: InputDecoration(labelText: "${"address_label".tr()} 2"),
              ),
              TextField(
                controller: cityController,
                decoration: InputDecoration(labelText: "city_label".tr()),
              ),
              TextField(
                controller: postalController,
                decoration: InputDecoration(labelText: "postal_label".tr()),
                keyboardType: TextInputType.number,
              ),
              const Divider(),
              TextField(
                controller: vehicleController,
                decoration: const InputDecoration(
                  labelText: "Registered Vehicle Number",
                  hintText: "e.g., WP CA-1234",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("cancel".tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              debugPrint('$_tag Profile update submitted.');
              final nav = Navigator.of(ctx);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              try {
                final result = await AuthService().updateProfile({
                  'addressLine1': line1Controller.text.trim(),
                  'addressLine2': line2Controller.text.trim(),
                  'city':         cityController.text.trim(),
                  'postalCode':   postalController.text.trim(),
                  'vehicleNumber': vehicleController.text.trim(),
                });

                if (result['success'] == true) {
                  debugPrint('$_tag Profile updated successfully. Updating local state and cache...');
                  setState(() {
                    _addressLine1 = line1Controller.text.trim();
                    _addressLine2 = line2Controller.text.trim();
                    _city         = cityController.text.trim();
                    _postalCode   = postalController.text.trim();

                    // Sync fields back into _userData so cache stays consistent
                    _userData['addressLine1'] = _addressLine1;
                    _userData['addressLine2'] = _addressLine2;
                    _userData['city']         = _city;
                    _userData['postalCode']   = _postalCode;
                    _userData['vehicleNumber'] = vehicleController.text.trim();
                  });

                  // Update cache with latest address
                  await SecureStorageService().cacheProfile(_userData);
                  debugPrint('$_tag Cache updated with new address.');

                  if (mounted) {
                    nav.pop();
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text("profile_updated".tr()),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint('$_tag Address update failed: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text("save".tr()),
          ),
        ],
      ),
    );
  }

  // ── UI HELPERS ─────────────────────────────────────────────────────────────

  ImageProvider _getProfileImage(String? base64String) {
    if (base64String != null && base64String.isNotEmpty) {
      try {
        final cleanBase64 = base64String.contains(',') ? base64String.split(',').last : base64String;
        return MemoryImage(base64Decode(cleanBase64));
      } catch (e) {
        debugPrint('$_tag _getProfileImage() — failed to decode base64: $e');
      }
    }
    return const AssetImage('assets/icon/icon.png');
  }

  Widget _buildSmallImageCard(BuildContext context, String label, String? base64) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 5),
        Container(
          width: 140,
          height: 85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            image: DecorationImage(
              image: _getProfileImage(base64),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _boxDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildDateColumn(BuildContext context, String label, String date, {bool isExpiry = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 5),
        Text(
          date,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isExpiry
                ? AppColors.errorRed
                : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildClassChip(String category, String issue, String expiry) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          width: 130,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.primaryGreenDark.withValues(alpha: 0.25)
                : AppColors.primaryGreenLight.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? AppColors.primaryGreen
                  : AppColors.primaryGreenDark.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                category,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? AppColors.primaryGreenLight : AppColors.primaryGreenDark,
                ),
              ),
              const SizedBox(height: 4),
              if (issue.isNotEmpty)
                Text(
                  "Iss: $issue",
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87),
                ),
              if (expiry.isNotEmpty)
                Text(
                  "Exp: $expiry",
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileRow(BuildContext context, IconData icon, String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.green[700], size: 20),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isHighlight
                      ? Colors.orange[800]
                      : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}