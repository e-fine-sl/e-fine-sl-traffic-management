import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../providers/theme_provider.dart';
import '../../config/app_constants.dart';
import '../auth/login_screen.dart';

class PoliceSettingsScreen extends StatefulWidget {
  const PoliceSettingsScreen({super.key});

  @override
  State<PoliceSettingsScreen> createState() => _PoliceSettingsScreenState();
}

class _PoliceSettingsScreenState extends State<PoliceSettingsScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final data = await _authService.getUserProfile();
      if (mounted) {
        setState(() {
          _userData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  ImageProvider _getProfileImage(String? profileImageBase64) {
    if (profileImageBase64 != null && profileImageBase64.isNotEmpty) {
      if (profileImageBase64.startsWith('data:image')) {
        try {
          final base64Data = profileImageBase64.split(',').last;
          return MemoryImage(base64Decode(base64Data));
        } catch (e) {
          return const NetworkImage(AppAssets.defaultProfileImage);
        }
      } else {
        return NetworkImage(profileImageBase64);
      }
    }
    return const NetworkImage(AppAssets.defaultProfileImage);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- USER PROFILE SECTION ---
                  _buildProfileCard(isDark),
                  const SizedBox(height: 32),

                  // --- PREFERENCES SECTION ---
                  Text(
                    'Preferences',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.blue.shade300 : AppColors.primaryBlue,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: Icon(
                            isDark ? Icons.dark_mode : Icons.light_mode,
                            color: isDark ? Colors.yellow.shade700 : Colors.orange,
                          ),
                          title: const Text('Dark Mode'),
                          subtitle: Text(isDark ? 'Deep Midnight Theme' : 'Light Theme'),
                          value: isDark,
                          onChanged: (val) => themeProvider.toggleTheme(val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- ABOUT SECTION ---
                  Text(
                    'System',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.blue.shade300 : AppColors.primaryBlue,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.info_outline, color: Colors.blue),
                          title: const Text('About App'),
                          subtitle: const Text(
                            'e-Fine SL Police Portal v1.0. A highly secure, real-time traffic management and emergency response system designed for Sri Lanka Police.',
                            style: TextStyle(fontSize: 13),
                          ),
                          isThreeLine: true,
                        ),
                        const Divider(indent: 56),
                        const ListTile(
                          leading: Icon(Icons.security, color: Colors.green),
                          title: Text('Security Status'),
                          subtitle: Text('Encrypted Connection Active'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // --- LOGOUT BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleLogout(context),
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        'LOGOUT SESSION',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.1,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFFDC2626) : AppColors.errorRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'v1.0.0 (Stable Build)',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard(bool isDark) {
    final name = _userData?['name'] ?? 'Officer Name';
    final badge = _userData?['badgeNumber'] ?? 'N/A';
    final stationData = _userData?['policeStation'];
    String station;
    if (stationData is Map) {
      station = stationData['name'] ?? 'Police Station';
    } else {
      station = stationData?.toString() ?? 'Police Station';
    }
    final profileImage = _userData?['profileImage'];

    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isDark 
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [AppColors.primaryBlue, AppColors.primaryBlueLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white24,
                backgroundImage: _getProfileImage(profileImage),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.badge, color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Badge: $badge',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.local_police, color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          station,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to end your current session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LOGOUT', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
