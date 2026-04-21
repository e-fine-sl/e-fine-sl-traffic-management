import 'dart:convert'; // For JSON decode
import 'package:flutter/material.dart';
import '../../services/police_locale_service.dart';
import 'package:mobile_app/widgets/police/police_text.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/auth_service.dart';

import 'new_fine.dart';
import 'fine_history_screen.dart';
import 'profile_screen.dart';
import 'qr_scanner_screen.dart';
import 'package:mobile_app/widgets/police/police_app_bar.dart';
import '../../config/app_constants.dart';
import '../../models/police_dashboard_model.dart';
import '../../services/police_dashboard_service.dart';
import 'package:mobile_app/widgets/police/daily_stats_widget.dart';
import 'package:mobile_app/widgets/police/hq_alerts_widget.dart';
import 'package:mobile_app/widgets/police/recent_fines_widget.dart';
import 'package:mobile_app/widgets/police/sos_fab.dart';

class PoliceHomeScreen extends StatefulWidget {
  const PoliceHomeScreen({super.key});

  @override
  State<PoliceHomeScreen> createState() => _PoliceHomeScreenState();
}

class _PoliceHomeScreenState extends State<PoliceHomeScreen> {
  final _storage = const FlutterSecureStorage();
  final AuthService _authService = AuthService();
  final PoliceDashboardService _dashboardService = PoliceDashboardService();

  String officerName = "Loading...";
  String badgeNumber = "";
  String officerRank = "";
  String? profileImageString;

  int _dailyFinesCount = 0;
  double _dailyTotalAmount = 0.0;
  List<Map<String, dynamic>>? _recentFines;
  List<HqAlertModel> _hqAlerts = [];
  bool _isLoadingDashboard = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoadingDashboard = true);

    // Added try-catch-finally block to prevent infinite loading state
    try {
      final hqAlertsFuture = _dashboardService.getHqAlerts();
      final dashboardDataFuture = _dashboardService.getPoliceDashboardData();
      
      final alerts = await hqAlertsFuture;
      final dashboardData = await dashboardDataFuture;

      if (mounted) {
        setState(() {
          _hqAlerts = alerts;
          
          if (dashboardData != null) {
            _recentFines = List<Map<String, dynamic>>.from(dashboardData['recentFines'] ?? []);
            
            final statsMap = dashboardData['dailyStats'] ?? {};
            _dailyFinesCount = statsMap['count'] ?? 0;
            _dailyTotalAmount = (statsMap['totalAmount'] ?? 0).toDouble();
          } else {
            _recentFines = null;
            _dailyFinesCount = 0;
            _dailyTotalAmount = 0.0;
          }
        });
      }
    } catch (e) {
      // Log the specific API error for debugging
      debugPrint('Error loading dashboard data: $e');
    } finally {
      // Ensure loading state is ALWAYS resolved, even on API failure
      if (mounted) {
        setState(() => _isLoadingDashboard = false);
      }
    }
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

        if (userData['badgeNumber'] != null &&
            userData['badgeNumber'].toString().isNotEmpty) {
          await _storage.write(
              key: 'badgeNumber', value: userData['badgeNumber'].toString());
        }

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
          _showErrorDialog(
              PoliceLocaleService.instance.translate('police.home_invalid_qr'));
        }
      } catch (e) {
        _showErrorDialog(
            PoliceLocaleService.instance.translate('police.home_qr_error'));
      }
    }
  }

  // --- Driver Details Dialog ---
  void _showDriverDetailsDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: PoliceText('police.home_driver_details_title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(
                PoliceLocaleService.instance.translate('police.home_nic_label'),
                data['nic'] ?? 'N/A'),
            const SizedBox(height: 10),
            _detailRow(
                PoliceLocaleService.instance
                    .translate('police.home_license_label'),
                data['license'] ?? 'N/A'),
            const SizedBox(height: 20),
            Center(
              child: PoliceText(
                'police.home_verify_hint',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: PoliceText('police.home_close'),
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
            child: PoliceText('police.home_issue_fine'),
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
        title: PoliceText('police.home_error_title'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: PoliceText('police.home_close'))
        ],
      ),
    );
  }

  ImageProvider _getProfileImage() {
    if (profileImageString != null && profileImageString!.isNotEmpty) {
      if (profileImageString!.startsWith('data:image')) {
        try {
          final base64Data = profileImageString!.split(',').last;
          return MemoryImage(base64Decode(base64Data));
        } catch (e) {
          // Changed default fallback image to a local asset to prevent network dependency
          return const AssetImage('assets/images/default_avatar.png');
        }
      } else if (profileImageString!.startsWith('http')) {
        return NetworkImage(profileImageString!);
      }
    }
    // Changed default fallback image to a local asset to prevent network dependency
    return const AssetImage('assets/images/default_avatar.png');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const PoliceAppBar(titleKey: 'police.home_appbar_title'),
      drawer: const Drawer(),
      floatingActionButton: SosFab(
        location: 'Current Location',
        officerName: officerName,
      ),
      body: RefreshIndicator(
        // Trigger both user data and dashboard data refresh
        onRefresh: () async {
          await _loadUserData();
          await _loadDashboardData();
        },
        child: SingleChildScrollView(
          // Ensure it can be scrolled and dragged even if content is short
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. HEADER SECTION (Profile & Greeting) ───────────────
              Container(
                padding: const EdgeInsets.only(
                    left: 20, right: 20, bottom: 30, top: 10),
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Row(
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
                          PoliceText(
                            'police.home_welcome',
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
              ),

              const SizedBox(height: 20),

              // ── 2. DASHBOARD BODY ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top: HQ Alerts
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: HQAlertsWidget(alerts: _hqAlerts),
                    ),

                    // Section 1: Daily Stats
                    DailyStatsWidget(
                        dailyFinesCount: _dailyFinesCount,
                        dailyTotalAmount: _dailyTotalAmount,
                        isLoading: _isLoadingDashboard),
                    const SizedBox(height: 30),

                    // Section 2: Quick Actions Grid
                    PoliceText(
                      'police.home_quick_actions',
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
                            title: 'police.home_new_fine',
                            icon: Icons.note_add_outlined,
                            iconColor: AppColors.errorRed,
                            bgColor: AppColors.pastelRed,
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const NewFineScreen()));
                            }),
                        _buildMenuCard(
                            title: 'police.home_check_license',
                            icon: Icons.qr_code_scanner,
                            iconColor: AppColors.primaryBlue,
                            bgColor: AppColors.pastelBlue,
                            onTap: _handleQRScan),
                        _buildMenuCard(
                            title: 'police.home_fine_history',
                            icon: Icons.history,
                            iconColor: AppColors.warningOrange,
                            bgColor: AppColors.pastelOrange,
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const FineHistoryScreen()));
                            }),
                        _buildMenuCard(
                          title: 'police.home_profile',
                          icon: Icons.person_outline,
                          iconColor: AppColors.primaryGreen,
                          bgColor: AppColors.pastelGreen,
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

                    const SizedBox(height: 30),

                    // Section 3: Recent Fines at the bottom
                    RecentFinesWidget(
                        fines: _recentFines, isLoading: _isLoadingDashboard),

                    const SizedBox(
                        height: 100), // Padding to prevent SOS FAB overlap
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
      required Color iconColor,
      required Color bgColor,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 35, color: iconColor),
            ),
            const SizedBox(height: 15),
            PoliceText(title,
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
