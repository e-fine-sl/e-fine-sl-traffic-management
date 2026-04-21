import 'package:flutter/material.dart';
import 'package:mobile_app/screens/driver/profile_screen.dart';
import 'package:mobile_app/services/auth_service.dart';
import 'package:mobile_app/services/secure_storage_service.dart';
import 'package:mobile_app/services/notification_service.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_app/services/fine_service.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:mobile_app/screens/driver/pay_fine_screen.dart';
import 'package:mobile_app/screens/driver/payment_history_screen.dart';
import 'package:mobile_app/screens/settings_screen.dart';
import 'package:mobile_app/screens/driver/wallet_screen.dart';
import 'package:mobile_app/widgets/demerit_status_card.dart';
import '../../config/app_constants.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  
  final _storage = const FlutterSecureStorage();
  

  String driverName = "Loading..."; 
  int _demeritPoints = DemeritConstants.defaultPoints;
  String _licenseStatus = 'ACTIVE';
  DateTime? _suspendedAt;
  bool _loadingStatus = true;

  Future<void> _loadDriverStatus() async {
    try {
      final response = await FineService().getDriverStatus();
      if (mounted) {
        setState(() {
          _demeritPoints = response['demeritPoints'] ?? DemeritConstants.defaultPoints;
          _licenseStatus = response['licenseStatus'] ?? 'ACTIVE';
          _suspendedAt = response['suspendedAt'] != null
              ? DateTime.parse(response['suspendedAt'])
              : null;
          _loadingStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingStatus = false);
      }
      debugPrint('Failed to load driver status: $e');
    }
  }

 String _getGreetingKey() {
    var hour = DateTime.now().hour;
    if (hour < 12) return 'greeting_morning';
    if (hour < 17) return 'greeting_afternoon';
    return 'greeting_evening';
  }

  bool hasPendingFines = false;
  int _fineCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadReadFines();
    _loadDriverStatus();
    // Initialize without notification
    FineService().getDriverPendingFines().then((fines) {
       if(mounted) {
         setState(() {
           _fineCount = fines.length;
           hasPendingFines = fines.isNotEmpty;
           _notifications = fines;
         });
       }
    });

    // Poll every 5 seconds (simulating realtime)
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkPendingFines();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- Session Management Part ---
  Future<void> _loadUserData() async {
    String? name = await _storage.read(key: PrefKeys.userName);
    if (mounted) {
      setState(() {
        driverName = name ?? "Driver"; 
      });
    }
  }







 // --- PROFILE DETAILS FUNCTION ---


  void _showProfileDetails() async {
    debugPrint('[HomeScreen] _showProfileDetails() called.');

    try {
      // 1. Check secure storage cache first
      debugPrint('[HomeScreen] Checking secure storage for cached profile...');
      final cached = await SecureStorageService().getCachedProfile();

      if (cached != null) {
        // Cache hit — navigate instantly, no loading dialog needed
        debugPrint('[HomeScreen] Cache hit — navigating to ProfileScreen instantly.');
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(userData: cached),
          ),
        );
        return;
      }

      // 2. Cache miss — fetch from API
      debugPrint('[HomeScreen] Cache miss — fetching profile from API...');
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      final userData = await AuthService().getUserProfile();
      debugPrint('[HomeScreen] Profile fetched from API. Caching now...');

      await SecureStorageService().cacheProfile(userData);
      debugPrint('[HomeScreen] Profile cached. Navigating to ProfileScreen.');

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userData: userData),
        ),
      );

    } catch (e) {
      debugPrint('[HomeScreen] Error in _showProfileDetails(): $e');
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }



  Future<void> _handleRefresh() async {
    setState(() => _loadingStatus = true);
    await Future.wait([
      _loadDriverStatus(),
      _checkPendingFines(),
    ]);
  }

  // Helper for Action Grid
  Widget _buildActionCard(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha((0.05 * 255).toInt()), blurRadius: 5, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color.withAlpha((0.1 * 255).toInt()),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _notifications = []; // Local storage for notifications

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey, // Add Key
      onEndDrawerChanged: _handleDrawerChange, // Handle Read/Unread
      endDrawer: _buildNotificationDrawer(), // Notification Side Panel
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, 
      appBar: AppBar(
        // backgroundColor uses Theme
        elevation: 0,
        title: const Text("e-Fine SL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          // --- LANGUAGE CHANGE BUTTON 
          TextButton(
            onPressed: () {
              if (context.locale.languageCode == 'en') {
                context.setLocale(const Locale('si'));
              } else {
                context.setLocale(const Locale('en'));
              }
            },
            child: Text(
              context.locale.languageCode == 'en' ? 'සිං' : 'ENG',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          
          // Notification Icon
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
                onPressed: () {
                  _scaffoldKey.currentState?.openEndDrawer(); // Open Side Drawer
                },
              ),
              if (_fineCount > 0)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.errorRed,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      "!",
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
            ],
          ),

          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
            }, 
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
        child: Column(
          children: [
            // 1. HEADER SECTION
            Container(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage('assets/icons/app_icon/app_logo_circle.png'), 
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- TRANSLATED TEXT ---
                      Text(
                        _getGreetingKey().tr(), 
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        driverName,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- PENDING FINE ALERT 
            if (hasPendingFines)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: InkWell(
                  onTap: () async {
                    if (_notifications.isEmpty) return;
                    bool? result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PayFineScreen(fine: _notifications.first),
                      ),
                    );
                    if (result == true) _refreshData();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.errorRed.withAlpha(40)
                          : AppColors.errorBg, 
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.errorRed.withAlpha((0.5 * 255).toInt())),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 30),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "unpaid_title".tr(),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.errorRed, fontSize: 16),
                              ),
                              Text(
                                "unpaid_msg".tr(),
                                style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: AppColors.errorRed, size: 16)
                      ],
                    ),
                  ),
                ),
              ),
            // ----------------------------------------

            const SizedBox(height: 20),

            // 2. DEMERIT POINTS METER
            _loadingStatus
                ? const Center(child: CircularProgressIndicator())
                : DemeritStatusCard(
                    points: _demeritPoints,
                    status: _licenseStatus,
                    suspendedAt: _suspendedAt,
                  ),

            const SizedBox(height: 20),

            // 3. ACTION GRID 
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  _buildActionCard(Icons.payment, "pay_fines".tr(), Colors.orange, () async {
                      if (_notifications.isEmpty) return;
                      bool? result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PayFineScreen(fine: _notifications.first),
                        ),
                      );
                      if (result == true) _refreshData();
                  }),
                  _buildActionCard(Icons.history, "history".tr(), Colors.blue, () { 
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => const PaymentHistoryScreen())
                      );
                  }),
                  _buildActionCard(Icons.wallet, "wallet".tr(), Colors.purple, () {
                      Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const WalletScreen()));
                  }),
                  _buildActionCard(Icons.report_problem, "report".tr(), AppColors.errorRed, () { }),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
      ),
      
      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "home".tr()),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: "wallet".tr()),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "profile".tr()),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.push(context,
              MaterialPageRoute(builder: (_) => const WalletScreen()));
          } else if (index == 2) { 
            _showProfileDetails();
          }
        },
      ),
    );
  }

  // ── Helper: human-readable "time ago" ──────────────────
  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return '';
    }
  }

  // --- Short & Sweet Notification Drawer ---
  Widget _buildNotificationDrawer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: AppTheme.drawerBackground(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 12, 16),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                const Text(
                  "Notifications",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_notifications.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_notifications.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                ),
              ],
            ),
          ),

          // ── List ───────────────────────────────────────
          Expanded(
            child: _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 64,
                            color: isDark ? Colors.grey[700] : Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text("All clear! No new fines.",
                            style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final fine = _notifications[index];
                      final String fineId = fine['_id'] ?? '';
                      final bool isRead = _readFineIds.contains(fineId);
                      final String offence = fine['offenseName'] ?? 'Traffic Fine';
                      final String amount = 'LKR ${fine['amount'] ?? '0'}';
                      final String timeAgo = _timeAgo(fine['date'] ?? fine['createdAt']);

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          Navigator.pop(context);
                          bool? result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PayFineScreen(fine: fine)),
                          );
                          if (result == true) _refreshData();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isRead
                                ? AppTheme.cardBackground(context)
                                : (isDark ? const Color(0xFF2D1515) : const Color(0xFFFFF0F0)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border(
                              left: BorderSide(
                                color: isRead ? Colors.transparent : AppColors.errorRed,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Icon
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: isRead
                                      ? (isDark ? Colors.grey[800] : Colors.grey[100])
                                      : AppColors.errorRed.withAlpha(25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isRead ? Icons.receipt_long_rounded : Icons.warning_amber_rounded,
                                  color: isRead ? Colors.grey : AppColors.errorRed,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Text content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            offence,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        if (!isRead)
                                          Container(
                                            width: 8, height: 8,
                                            margin: const EdgeInsets.only(left: 6),
                                            decoration: const BoxDecoration(
                                              color: AppColors.errorRed,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          amount,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isRead ? AppTheme.textSecondary(context) : AppColors.errorRed,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          timeAgo,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textHint(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right_rounded,
                                  size: 20, color: Colors.grey[400]),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              "v1.2.0-beta",
              style: TextStyle(
                color: isDark ? Colors.grey[600] : Colors.grey[400],
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Set<String> _readFineIds = {};

  Future<void> _loadReadFines() async {
    String? storedIds = await _storage.read(key: 'read_fines');
    if (storedIds != null && storedIds.isNotEmpty) {
      setState(() {
        _readFineIds = storedIds.split(',').toSet();
      });
    }
  }

  void _handleDrawerChange(bool isOpened) {
     if (!isOpened) { // When Drawer Closes
        // Mark all current fines as read
        setState(() {
           for (var fine in _notifications) {
              if (fine['_id'] != null) {
                _readFineIds.add(fine['_id']);
              }
           }
           _fineCount = 0; // Clear badge
        });
        // Save to storage
        _storage.write(key: 'read_fines', value: _readFineIds.join(','));
     }
  }

  // Check for new fines — also fires device notification
  Future<void> _checkPendingFines() async {
      try {
        final fines = await FineService().getDriverPendingFines();
        
        // Calculate Badge Count (Unread Only)
        int unreadCount = 0;
        List<Map<String, dynamic>> newFines = [];
        for (var fine in fines) {
           if (fine['_id'] != null && !_readFineIds.contains(fine['_id'])) {
              unreadCount++;
              newFines.add(fine);
           }
        }

        if (mounted) {
          // If totally new fines appeared since last check
          if (unreadCount > _fineCount && _fineCount >= 0) {
             _showProfessionalSnackbar();

             // ── Device notification bar ─────────────────────
             for (var fine in newFines) {
               final offence = fine['offenseName'] ?? 'Traffic Fine';
               final amount  = fine['amount'] ?? '0';
               NotificationService().showFineNotification(
                 title: '⚠️ New Fine: $offence',
                 body: 'Amount: LKR $amount — Tap to pay now.',
                 id: fine['_id'].hashCode,
               );
             }
          }
          
          setState(() {
            hasPendingFines = fines.isNotEmpty;
            _fineCount = unreadCount; // Badge shows unread count
            _notifications = fines; 
          });
        }
      } catch (e) {
        // Silent error
      }
  }

  void _refreshData() {
     _checkPendingFines();
  }

  // Modern Top Snackbar implementation (simulated with standard SnackBar but styled)
  void _showProfessionalSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.campaign, color: Colors.white),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("New Fine Received", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Check your notification drawer.", style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                _scaffoldKey.currentState?.openEndDrawer();
              },
              child: const Text("VIEW", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            )
          ],
        ),
        backgroundColor: Colors.grey[900],
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150, // Force it to TOP area roughly
          left: 10,
          right: 10
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 5),
      )
    );
  }
}