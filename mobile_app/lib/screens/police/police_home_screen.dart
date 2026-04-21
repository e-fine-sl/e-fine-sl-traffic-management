// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/police/police_home_screen.dart
// e-Fine SL — Police Home Screen
//
// Dashboard stats are computed LOCALLY from FineService.getOfficerFineHistory():
//   • _dailyFinesCount  → fines where fine['date'] matches today (Y/M/D)
//   • _dailyTotalAmount → sum of fine['amount'] for those today-fines
//   • _recentFines      → first 3 items of the full history list
//
// This bypasses the dashboard-stats API entirely, using the proven
// /fines/history endpoint that already works in FineHistoryScreen.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../services/auth_service.dart';
import '../../services/fine_service.dart';
import '../../services/police_dashboard_service.dart'; // kept only for SOS & HQ alerts
import '../../services/police_locale_service.dart';
import '../../config/app_constants.dart';
import '../../models/police_dashboard_model.dart';

import 'new_fine.dart';
import 'fine_history_screen.dart';
import 'profile_screen.dart';
import 'qr_scanner_screen.dart';

class PoliceHomeScreen extends StatefulWidget {
  const PoliceHomeScreen({super.key});

  @override
  State<PoliceHomeScreen> createState() => _PoliceHomeScreenState();
}

class _PoliceHomeScreenState extends State<PoliceHomeScreen> {
  final _storage = const FlutterSecureStorage();
  final AuthService _authService = AuthService();

  // FineService drives all dashboard stats now
  final FineService _fineService = FineService();

  // PoliceDashboardService is kept only for SOS and HQ alerts
  final PoliceDashboardService _dashboardService = PoliceDashboardService();

  // ── Officer Profile State ──────────────────────────────────────────────────
  String officerName = 'Loading...';
  String badgeNumber = '';
  String officerRank = '';
  String? profileImageString;

  // ── Dashboard State (computed locally from fine history) ───────────────────
  int _dailyFinesCount = 0;
  double _dailyTotalAmount = 0.0;
  List<Map<String, dynamic>> _recentFines = [];
  List<HqAlertModel> _hqAlerts = [];

  // ── Loading Flags ──────────────────────────────────────────────────────────
  bool _isLoadingProfile = true;
  bool _isLoadingDashboard = true;

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  /// Loads profile first (so badge is in storage), then dashboard.
  Future<void> _initScreen() async {
    await _loadUserData();
    await _loadDashboardData();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1 — Load officer profile
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadUserData() async {
    debugPrint('[PoliceHomeScreen] _loadUserData() START');

    // Show cached values instantly
    final storedName  = await _storage.read(key: PrefKeys.userName);
    final storedBadge = await _storage.read(key: 'badgeNumber');
    final storedRank  = await _storage.read(key: 'position');
    final storedImg   = await _storage.read(key: 'serverProfileImage');

    if (mounted) {
      setState(() {
        officerName        = storedName  ?? 'Officer';
        badgeNumber        = storedBadge ?? '';
        officerRank        = storedRank  ?? 'Officer';
        profileImageString = storedImg;
        _isLoadingProfile  = false;
      });
    }

    // Refresh from API in the background
    try {
      final userData  = await _authService.getUserProfile();
      final freshBadge = userData['badgeNumber']?.toString() ?? '';
      final freshName  = userData['name']?.toString()        ?? officerName;
      final freshRank  = userData['position']?.toString()    ?? officerRank;
      final freshImg   = userData['profileImage']?.toString();

      if (freshBadge.isNotEmpty) {
        await _storage.write(key: 'badgeNumber',          value: freshBadge);
        await _storage.write(key: PrefKeys.badgeNumber,   value: freshBadge);
        debugPrint('[PoliceHomeScreen] Badge refreshed: "$freshBadge"');
      }
      if (freshImg != null && freshImg.isNotEmpty) {
        await _storage.write(key: 'serverProfileImage', value: freshImg);
      }

      if (mounted) {
        setState(() {
          officerName        = freshName;
          badgeNumber        = freshBadge.isNotEmpty ? freshBadge : badgeNumber;
          officerRank        = freshRank;
          profileImageString = freshImg;
        });
      }
    } catch (e) {
      debugPrint('[PoliceHomeScreen] getUserProfile() failed (using cache): $e');
    }

    debugPrint('[PoliceHomeScreen] _loadUserData() END. badge="$badgeNumber"');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2 — Load dashboard by computing stats from fine history locally
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadDashboardData() async {
    debugPrint('[PoliceHomeScreen] _loadDashboardData() START');
    if (mounted) setState(() => _isLoadingDashboard = true);

    // HQ Alerts are non-critical — run in background, never block the main call
    _dashboardService.getHqAlerts().then((alerts) {
      if (mounted) setState(() => _hqAlerts = alerts);
    }).catchError((e) {
      debugPrint('[PoliceHomeScreen] getHqAlerts() skipped: $e');
    });

    try {
      // ── Fetch the full fine history (the proven, working endpoint) ─────────
      debugPrint('[PoliceHomeScreen] Calling FineService.getOfficerFineHistory()...');
      final List<Map<String, dynamic>> history =
          await _fineService.getOfficerFineHistory();

      debugPrint('[PoliceHomeScreen] History fetched: ${history.length} records');

      // ── Compute "Today" filter ─────────────────────────────────────────────
      final now   = DateTime.now();
      final today = DateTime(now.year, now.month, now.day); // midnight, local

      int    todayCount  = 0;
      double todayAmount = 0.0;

      for (final fine in history) {
        // The 'date' field is an ISO-8601 string, e.g. "2026-04-21T09:12:00.000Z"
        final rawDate = fine['date']?.toString() ?? fine['createdAt']?.toString();

        if (rawDate != null && rawDate.isNotEmpty) {
          try {
            final fineDate = DateTime.parse(rawDate).toLocal();
            final fineDateOnly =
                DateTime(fineDate.year, fineDate.month, fineDate.day);

            if (fineDateOnly == today) {
              todayCount++;

              // Safely parse amount — may come as int, double, or string
              final rawAmount = fine['amount'];
              final parsedAmount = rawAmount is num
                  ? rawAmount.toDouble()
                  : double.tryParse(rawAmount?.toString() ?? '0') ?? 0.0;

              todayAmount += parsedAmount;

              debugPrint(
                  '[PoliceHomeScreen]   + Today fine: amount=$parsedAmount, date=$rawDate');
            }
          } catch (e) {
            debugPrint('[PoliceHomeScreen]   ⚠ Could not parse date "$rawDate": $e');
          }
        }
      }

      // ── Recent fines = first 3 items of full history ───────────────────────
      final recentFines = history.take(3).toList();

      debugPrint('[PoliceHomeScreen] ✅ Computed stats:');
      debugPrint('   _dailyFinesCount  = $todayCount');
      debugPrint('   _dailyTotalAmount = $todayAmount');
      debugPrint('   _recentFines.length = ${recentFines.length}');

      if (mounted) {
        setState(() {
          _dailyFinesCount  = todayCount;
          _dailyTotalAmount = todayAmount;
          _recentFines      = recentFines;
        });
      }
    } catch (e) {
      debugPrint('[PoliceHomeScreen] ❌ _loadDashboardData() EXCEPTION: $e');
      if (mounted) {
        setState(() {
          _dailyFinesCount  = 0;
          _dailyTotalAmount = 0.0;
          _recentFines      = [];
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingDashboard = false);
      debugPrint('[PoliceHomeScreen] _loadDashboardData() END');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pull-to-refresh
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _refresh() async {
    await _loadUserData();
    await _loadDashboardData();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QR SCAN HANDLER
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _handleQRScan() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    if (result != null && mounted) {
      try {
        final Map<String, dynamic> data = jsonDecode(result);
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

  // ─────────────────────────────────────────────────────────────────────────
  // DIALOGS
  // ─────────────────────────────────────────────────────────────────────────
  void _showDriverDetailsDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(PoliceLocaleService.instance
            .translate('police.home_driver_details_title')),
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
              child: Text(
                PoliceLocaleService.instance
                    .translate('police.home_verify_hint'),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
                PoliceLocaleService.instance.translate('police.home_close')),
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
            child: Text(PoliceLocaleService.instance
                .translate('police.home_issue_fine')),
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
        Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            PoliceLocaleService.instance.translate('police.home_error_title')),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                  PoliceLocaleService.instance.translate('police.home_close')))
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROFILE IMAGE
  // ─────────────────────────────────────────────────────────────────────────
  ImageProvider _getProfileImage() {
    if (profileImageString != null && profileImageString!.isNotEmpty) {
      if (profileImageString!.startsWith('data:image')) {
        try {
          final base64Data = profileImageString!.split(',').last;
          return MemoryImage(base64Decode(base64Data));
        } catch (_) {
          return const AssetImage('assets/images/default_avatar.png');
        }
      } else if (profileImageString!.startsWith('http')) {
        return NetworkImage(profileImageString!);
      }
    }
    return const AssetImage('assets/images/default_avatar.png');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATUS COLOR HELPER
  // ─────────────────────────────────────────────────────────────────────────
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'UNPAID':
      default:
        return Colors.red;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
            PoliceLocaleService.instance.translate('police.home_appbar_title')),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Dashboard',
            onPressed: _refresh,
          ),
        ],
      ),
      drawer: const Drawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final success = await _dashboardService.registerSosAlert(
              'Current Location', officerName);
          if (success && mounted) {
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('SOS Alert Sent!'),
                  backgroundColor: AppColors.errorRed),
            );
          }
        },
        backgroundColor: AppColors.errorRed,
        child: const Icon(Icons.sos, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. HEADER SECTION ──────────────────────────────────────
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
                          Text(
                            PoliceLocaleService.instance
                                .translate('police.home_welcome'),
                            style:
                                TextStyle(color: Colors.blue[100], fontSize: 14),
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
                            '$officerRank${badgeNumber.isNotEmpty ? ' | $badgeNumber' : ''}',
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

              // ── 2. DASHBOARD BODY ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HQ Alerts (only shown when data is available)
                    if (_hqAlerts.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Colors.orange),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _hqAlerts.first.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(_hqAlerts.first.message,
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),

                    // ── STAT CARDS ──────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            label: 'Fines Today',
                            value: _dailyFinesCount.toString(),
                            icon: Icons.assignment_late_outlined,
                            color: Colors.blue,
                            isLoading: _isLoadingDashboard,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildStatCard(
                            label: 'Total Amount',
                            value:
                                'LKR ${_dailyTotalAmount.toStringAsFixed(0)}',
                            icon: Icons.account_balance_wallet_outlined,
                            color: Colors.green,
                            isLoading: _isLoadingDashboard,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // ── QUICK ACTIONS ───────────────────────────────────
                    Text(
                      PoliceLocaleService.instance
                          .translate('police.home_quick_actions'),
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
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const NewFineScreen())),
                        ),
                        _buildMenuCard(
                          title: 'police.home_check_license',
                          icon: Icons.qr_code_scanner,
                          iconColor: AppColors.primaryBlue,
                          bgColor: AppColors.pastelBlue,
                          onTap: _handleQRScan,
                        ),
                        _buildMenuCard(
                          title: 'police.home_fine_history',
                          icon: Icons.history,
                          iconColor: AppColors.warningOrange,
                          bgColor: AppColors.pastelOrange,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const FineHistoryScreen())),
                        ),
                        _buildMenuCard(
                          title: 'police.home_profile',
                          icon: Icons.person_outline,
                          iconColor: AppColors.primaryGreen,
                          bgColor: AppColors.pastelGreen,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ProfileScreen()))
                              .then((_) => _loadUserData()),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // ── RECENT FINES ────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Fines',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (!_isLoadingDashboard && _recentFines.isNotEmpty)
                          Text(
                            'Showing ${_recentFines.length} of latest',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // Loading state
                    if (_isLoadingDashboard)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(30.0),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Loading dashboard...',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    // Empty state
                    else if (_recentFines.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined,
                                color: Colors.grey[400], size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No recent fines found',
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Fines you issue will appear here',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    // Data state
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentFines.length,
                        itemBuilder: (context, index) {
                          final fine = _recentFines[index];

                          // Field names match the /fines/history API response
                          final amount =
                              fine['amount']?.toString() ?? '0';
                          final offenseName =
                              fine['offenseName']?.toString() ?? 'Offense';
                          final vehicleNumber =
                              fine['vehicleNumber']?.toString() ?? 'N/A';
                          final status =
                              fine['status']?.toString() ?? 'UNPAID';
                          final statusColor = _getStatusColor(status);

                          // Format the date if present
                          String dateLabel = '';
                          final rawDate = fine['date']?.toString() ??
                              fine['createdAt']?.toString();
                          if (rawDate != null && rawDate.isNotEmpty) {
                            try {
                              final dt = DateTime.parse(rawDate).toLocal();
                              dateLabel =
                                  '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                            } catch (_) {
                              dateLabel = rawDate;
                            }
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor:
                                    statusColor.withValues(alpha: 0.15),
                                child: Icon(Icons.description_outlined,
                                    color: statusColor, size: 20),
                              ),
                              title: Text(
                                offenseName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(vehicleNumber,
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12)),
                                  if (dateLabel.isNotEmpty)
                                    Text(dateLabel,
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 11)),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'LKR $amount',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: statusColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 100), // FAB clearance
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REUSABLE WIDGETS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
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
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 35, color: iconColor),
            ),
            const SizedBox(height: 15),
            Text(
                PoliceLocaleService.instance.translate(title),
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

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isLoading,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 15),
          if (isLoading)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }
}
