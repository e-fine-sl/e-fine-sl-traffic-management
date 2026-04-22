import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// --- Services ---
import 'package:mobile_app/services/police_locale_service.dart';
import 'package:mobile_app/services/auth_service.dart';
import 'package:mobile_app/services/police_dashboard_service.dart';
import 'package:mobile_app/services/fine_service.dart'; // FineService is used for reliable data fetching

// --- Config & Models ---
import 'package:mobile_app/config/app_constants.dart';
import 'package:mobile_app/models/police_dashboard_model.dart';

// --- Screens ---
import 'package:mobile_app/screens/police/new_fine.dart';
import 'package:mobile_app/screens/police/fine_history_screen.dart';
import 'package:mobile_app/screens/police/profile_screen.dart';
import 'package:mobile_app/screens/police/qr_scanner_screen.dart';

class PoliceHomeScreen extends StatefulWidget {
  const PoliceHomeScreen({super.key});

  @override
  State<PoliceHomeScreen> createState() => _PoliceHomeScreenState();
}

class _PoliceHomeScreenState extends State<PoliceHomeScreen> {
  final _storage = const FlutterSecureStorage();
  final AuthService _authService = AuthService();
  
  // DashboardService is kept ONLY for HQ Alerts and the SOS button functionality
  final PoliceDashboardService _dashboardService = PoliceDashboardService();
  
  // FineService is used to reliably calculate dashboard stats locally from history
  final FineService _fineService = FineService();

  // --- User State Variables ---
  String officerName = "Loading...";
  String badgeNumber = "";
  String officerRank = "";
  String? profileImageString;

  // --- Dashboard State Variables ---
  int _dailyFinesCount = 0;
  double _dailyTotalAmount = 0.0;
  List<Map<String, dynamic>>? _recentFines;
  List<HqAlertModel> _hqAlerts = [];
  bool _isLoadingDashboard = true;

  @override
  void initState() {
    super.initState();
    _initScreen(); 
  }

  // --- Initialization Sequence ---
  // Forces user data to load BEFORE dashboard data to prevent race conditions
  Future<void> _initScreen() async {
    debugPrint('[PoliceHomeScreen] initState: Loading user data first...');
    await _loadUserData();
    
    debugPrint('[PoliceHomeScreen] initState: User data loaded, now loading dashboard...');
    await _loadDashboardData();
    
    // Fetch HQ Alerts in a non-blocking way (doesn't hold up the UI)
    _dashboardService.getHqAlerts().then((alerts) {
      if (mounted) setState(() => _hqAlerts = alerts);
    }).catchError((e) {
      debugPrint('[PoliceHomeScreen] HQ Alerts failed: $e');
    });
  }

  // --- BULLETPROOF DASHBOARD CALCULATION LOGIC ---
  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoadingDashboard = true);

    try {
      // 1. Fetch the complete fine history reliably using FineService
      final allFines = await _fineService.getOfficerFineHistory();

      // 2. Prepare today's date in local time as a pure String (Format: YYYY-MM-DD)
      final now = DateTime.now();
      final String todayString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      double totalAmount = 0.0;
      int count = 0;

      // 3. Loop through all fines and safely parse the dates
      for (var fine in allFines) {
        try {
          // Safely check if the backend sent 'date' or 'createdAt'
          final dateValue = fine['date'] ?? fine['createdAt'];
          
          if (dateValue != null) {
            DateTime fineDate;
            String valStr = dateValue.toString();
            int? timestamp = int.tryParse(valStr);

            // CASE A: Date came as a UNIX Timestamp (e.g., 1713654000000)
            if (timestamp != null && valStr.length >= 10) {
              // Convert seconds to milliseconds if necessary
              if (valStr.length == 10) timestamp = timestamp * 1000;
              fineDate = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
            } 
            // CASE B: Date came as an ISO String (e.g., 2026-04-21T18:30:00Z)
            else {
              fineDate = DateTime.parse(valStr).toLocal();
            }

            // Convert the parsed fine date to a pure String (Format: YYYY-MM-DD)
            final String fineDateString = "${fineDate.year}-${fineDate.month.toString().padLeft(2, '0')}-${fineDate.day.toString().padLeft(2, '0')}";

            // 4. Match the strings. If they match, increment stats.
            if (fineDateString == todayString) {
              count++;
              totalAmount += double.tryParse(fine['amount']?.toString() ?? '0') ?? 0.0;
            }
          }
        } catch (e) {
          // If parsing fails for one specific record, print it and continue to the next
          debugPrint('❌ Error Parsing Date: $e -> Value was: ${fine['date']}');
        }
      }

      // 5. Get the last 3 recent fines (Since history is already sorted descending by date)
      final recent3 = allFines.take(3).toList();

      // 6. Update the UI State
      if (mounted) {
        setState(() {
          _dailyFinesCount = count;
          _dailyTotalAmount = totalAmount;
          _recentFines = recent3;
        });
        debugPrint('[PoliceHomeScreen] ✅ FINAL STATS: Count=$count, Amount=$totalAmount');
      }
    } catch (e) {
      debugPrint('[PoliceHomeScreen] ❌ ERROR calculating stats locally: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDashboard = false);
    }
  }

  // --- Load User Data ---
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

        if (userData['badgeNumber'] != null && userData['badgeNumber'].toString().isNotEmpty) {
          await _storage.write(key: 'badgeNumber', value: userData['badgeNumber'].toString());
        }
        if (profileImageString != null) {
          await _storage.write(key: 'serverProfileImage', value: profileImageString);
        }
      }
    } catch (e) {
      debugPrint('[PoliceHomeScreen] Profile fetch fallback triggered (silently handled)');
    }
  }

  // --- QR Scanner Logic ---
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
          _showErrorDialog(PoliceLocaleService.instance.translate('police.home_invalid_qr'));
        }
      } catch (e) {
        _showErrorDialog(PoliceLocaleService.instance.translate('police.home_qr_error'));
      }
    }
  }

  // --- UI Dialogs ---
  void _showDriverDetailsDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(PoliceLocaleService.instance.translate('police.home_driver_details_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(PoliceLocaleService.instance.translate('police.home_nic_label'), data['nic'] ?? 'N/A'),
            const SizedBox(height: 10),
            _detailRow(PoliceLocaleService.instance.translate('police.home_license_label'), data['license'] ?? 'N/A'),
            const SizedBox(height: 20),
            Center(
              child: Text(
                PoliceLocaleService.instance.translate('police.home_verify_hint'),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(PoliceLocaleService.instance.translate('police.home_close')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => NewFineScreen(scannedLicenseNumber: data['license'])));
            },
            child: Text(PoliceLocaleService.instance.translate('police.home_issue_fine')),
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
        title: Text(PoliceLocaleService.instance.translate('police.home_error_title')),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(PoliceLocaleService.instance.translate('police.home_close')))
        ],
      ),
    );
  }

  // Parses the profile image string based on format (base64 or network URL)
  ImageProvider _getProfileImage() {
    if (profileImageString != null && profileImageString!.isNotEmpty) {
      if (profileImageString!.startsWith('data:image')) {
        try {
          final base64Data = profileImageString!.split(',').last;
          return MemoryImage(base64Decode(base64Data));
        } catch (e) {
          return const AssetImage('assets/images/default_avatar.png');
        }
      } else if (profileImageString!.startsWith('http')) {
        return NetworkImage(profileImageString!);
      }
    }
    return const AssetImage('assets/images/default_avatar.png');
  }

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

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(PoliceLocaleService.instance.translate('police.home_appbar_title')),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      drawer: const Drawer(),
      
      // SOS Floating Action Button
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final success = await _dashboardService.registerSosAlert('Current Location', officerName);
          if (success && mounted) {
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
      
      // Pull to Refresh triggers the entire _initScreen sequence to refresh all data
      body: RefreshIndicator(
        onRefresh: _initScreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. HEADER SECTION ---
              Container(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30, top: 10),
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
                            PoliceLocaleService.instance.translate('police.home_welcome'),
                            style: TextStyle(color: Colors.blue[100], fontSize: 14),
                          ),
                          Text(
                            officerName,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "$officerRank | $badgeNumber",
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- 2. DASHBOARD BODY ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HQ Alerts Display
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
                                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                const SizedBox(width: 10),
                                Text(
                                  _hqAlerts.first.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(_hqAlerts.first.message, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),

                    // Daily Stats Cards (Count & Total Amount)
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
                            value: 'LKR ${_dailyTotalAmount.toStringAsFixed(0)}',
                            icon: Icons.account_balance_wallet_outlined,
                            color: Colors.green,
                            isLoading: _isLoadingDashboard,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Quick Actions Grid Menu
                    Text(
                      PoliceLocaleService.instance.translate('police.home_quick_actions'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
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
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) => const NewFineScreen())).then((_) => _initScreen());
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
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) => const FineHistoryScreen()));
                            }),
                        _buildMenuCard(
                          title: 'police.home_profile',
                          icon: Icons.person_outline,
                          iconColor: AppColors.primaryGreen,
                          bgColor: AppColors.pastelGreen,
                          onTap: () {
                            Navigator.push(context,
                                MaterialPageRoute(builder: (context) => const ProfileScreen())).then((_) {
                              _initScreen();
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // --- 3. RECENT FINES LIST ---
                    const Text(
                      'Recent Fines',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    
                    if (_isLoadingDashboard)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_recentFines == null || _recentFines!.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined, color: Colors.grey[400], size: 40),
                            const SizedBox(height: 10),
                            Text(
                              'No recent fines found',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Fines issued today will appear here',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentFines!.length,
                        itemBuilder: (context, index) {
                          final fine = _recentFines![index];
                          final amount = fine['amount']?.toString() ?? '0';
                          final offenseName = fine['offenseName'] ?? 'Offense';
                          final vehicleNumber = fine['vehicleNumber'] ?? 'N/A';
                          final status = fine['status'] ?? 'UNPAID';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(status),
                                child: const Icon(Icons.description_outlined, color: Colors.white),
                              ),
                              title: Text(
                                offenseName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                vehicleNumber,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'LKR $amount',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _getStatusColor(status),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 100), // Bottom padding to prevent FAB overlap
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Reusable UI Widgets ---
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
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 35, color: iconColor),
            ),
            const SizedBox(height: 15),
            Text(PoliceLocaleService.instance.translate(title),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
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
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 15),
          if (isLoading)
            const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }
}