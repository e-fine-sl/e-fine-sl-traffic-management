import 'dart:convert'; // For JSON decode
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/auth_service.dart';
import '../../widgets/police/language_selector_widget.dart';

import 'new_fine.dart';
import 'fine_history_screen.dart';
import 'profile_screen.dart';
import 'qr_scanner_screen.dart';
import '../../config/app_constants.dart';

class PoliceHomeScreen extends StatefulWidget {
  const PoliceHomeScreen({super.key});

  @override
  State<PoliceHomeScreen> createState() => _PoliceHomeScreenState();
}

class _PoliceHomeScreenState extends State<PoliceHomeScreen> {
  final _storage = const FlutterSecureStorage();
  final AuthService _authService = AuthService();

  String officerName = "Loading...";
  String badgeNumber = "";
  String officerRank = "";
  String? profileImageString;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // --- Data Fetching Section ---
  Future<void> _loadUserData() async {
    String? storedName = await _storage.read(key: PrefKeys.userName);
    String? storedBadge = await _storage.read(key: 'badgeNumber');
    String? storedRank = await _storage.read(key: 'position');
    String? serverImg = await _storage.read(key: 'serverProfileImage');

    if (mounted) {
      setState(() {
        officerName = storedName ?? "Officer";
        badgeNumber = storedBadge ?? "";
        officerRank = storedRank ?? "Officer";
        profileImageString = serverImg;
      });
    }

    try {
      final userData = await _authService.getUserProfile();

      if (mounted) {
        setState(() {
          officerName = userData['name'] ?? officerName;
          badgeNumber = userData['badgeNumber'] ?? badgeNumber;
          officerRank = userData['position'] ?? officerRank;
          profileImageString = userData['profileImage'];
        });

        if (profileImageString != null) {
          await _storage.write(
              key: 'serverProfileImage', value: profileImageString);
        }
      }
    } catch (e) {
      // Silently handle — cached data is sufficient.
    }
  }

  // --- QR Scan Logic ---
  Future<void> _handleQRScan() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    if (result != null && mounted) {
      try {
        Map<String, dynamic> data = jsonDecode(result);

        if (data['type'] == 'driver_identity') {
          _showDriverDetailsDialog(data);
        } else {
          _showErrorDialog('police.home_invalid_qr'.tr());
        }
      } catch (e) {
        _showErrorDialog('police.home_qr_error'.tr());
      }
    }
  }

  // --- Driver Details Dialog ---
  void _showDriverDetailsDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('police.home_driver_details_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('police.home_nic_label'.tr(), data['nic'] ?? 'N/A'),
            const SizedBox(height: 10),
            _detailRow(
                'police.home_license_label'.tr(), data['license'] ?? 'N/A'),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'police.home_verify_hint'.tr(),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('police.home_close'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => NewFineScreen(
                          scannedLicenseNumber: data['license'])));
            },
            child: Text('police.home_issue_fine'.tr()),
          )
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 10),
        Text(value),
      ],
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('police.home_error_title'.tr()),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('police.home_close'.tr()))
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    await _loadUserData();
  }

  ImageProvider _getProfileImage() {
    if (profileImageString != null && profileImageString!.isNotEmpty) {
      if (profileImageString!.startsWith('data:image')) {
        try {
          final base64Data = profileImageString!.split(',').last;
          return MemoryImage(base64Decode(base64Data));
        } catch (e) {
          return const NetworkImage(
              'https://cdn-icons-png.flaticon.com/512/206/206853.png');
        }
      } else if (profileImageString!.startsWith('http')) {
        return NetworkImage(profileImageString!);
      }
    }
    return const NetworkImage(
        'https://cdn-icons-png.flaticon.com/512/206/206853.png');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        title: Text(
          'police.home_appbar_title'.tr(),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          const LanguageSelectorWidget(),
          IconButton(
            icon:
                const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      drawer: const Drawer(),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HEADER SECTION ───────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.only(left: 20, right: 20, bottom: 30),
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            backgroundImage: _getProfileImage(),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'police.home_welcome'.tr(),
                                style: TextStyle(
                                    color: Colors.blue[100], fontSize: 14),
                              ),
                              Text(
                                officerName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "$officerRank | $badgeNumber",
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── DASHBOARD GRID ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'police.home_quick_actions'.tr(),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 15),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      children: [
                        _buildMenuCard(
                            title: 'police.home_new_fine'.tr(),
                            icon: Icons.note_add_outlined,
                            color: AppColors.errorRed,
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const NewFineScreen()));
                            }),

                        _buildMenuCard(
                            title: 'police.home_check_license'.tr(),
                            icon: Icons.qr_code_scanner,
                            color: AppColors.primaryBlue,
                            onTap: _handleQRScan),

                        _buildMenuCard(
                            title: 'police.home_fine_history'.tr(),
                            icon: Icons.history,
                            color: AppColors.warningOrange,
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const FineHistoryScreen()));
                            }),

                        _buildMenuCard(
                          title: 'police.home_profile'.tr(),
                          icon: Icons.person_outline,
                          color: AppColors.primaryGreen,
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ProfileScreen())).then((_) {
                              _loadUserData();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 35, color: color),
            ),
            const SizedBox(height: 15),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
