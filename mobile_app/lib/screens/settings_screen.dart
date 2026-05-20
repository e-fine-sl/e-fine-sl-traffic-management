import 'package:flutter/material.dart';
import 'package:mobile_app/services/auth_service.dart';
import 'package:mobile_app/services/notification_service.dart';
import 'package:mobile_app/screens/auth/login_screen.dart';
import 'package:mobile_app/screens/driver/profile_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import '../config/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = NotificationService().isEnabled;
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context, 
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false 
      );
    }
  }

  Future<void> _toggleNotifications(bool val) async {
    await NotificationService().setEnabled(val);
    setState(() => _notificationsEnabled = val);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              val ? Icons.notifications_active : Icons.notifications_off,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text("Notifications turned ${val ? 'ON' : 'OFF'}"),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1: Account
          _buildSectionHeader("Account"),
          _buildListTile(
            icon: Icons.person_outline, 
            title: "Profile", 
            subtitle: "View and edit your profile",
            onTap: _navigateToProfile,
          ),

          const Divider(),

          // Section 2: Appearance
          _buildSectionHeader("Appearance"),
          // Dark Mode
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.primaryGreen),
            title: const Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.bold)),
            value: isDark,
            onChanged: (val) {
              context.read<ThemeProvider>().toggleTheme(val);
            },
            activeThumbColor: AppColors.primaryGreen,
          ),
          // Language
          _buildListTile(
            icon: Icons.language, 
            title: "Language", 
            subtitle: context.locale.languageCode == 'en' ? "English" : "Sinhala (සිංහල)",
            onTap: _showLanguageDialog
          ),

          const Divider(),

          // Section 3: General
          _buildSectionHeader("General"),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined, color: AppColors.primaryGreen),
            title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              _notificationsEnabled
                  ? "Show fines in device notification bar"
                  : "Device notifications disabled",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            value: _notificationsEnabled,
            onChanged: _toggleNotifications,
            activeThumbColor: AppColors.primaryGreen,
          ),
          _buildListTile(
            icon: Icons.info_outline, 
            title: "About App", 
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: "e-Fine SL",
                applicationVersion: "1.0.0",
                applicationLegalese: "© 2026 e-Fine SL Project"
              );
            }
          ),

          const Divider(),

          // Section 4: Logout
          const SizedBox(height: 20),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.logout, color: AppColors.errorRed),
            ),
            title: const Text("Logout", style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Text(title, style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildListTile({required IconData icon, required String title, String? subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.1), 
          borderRadius: BorderRadius.circular(8)
        ),
        child: Icon(icon, color: AppColors.primaryGreen),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  Future<void> _navigateToProfile() async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)));
    
    try {
      final data = await _authService.getUserProfile();
      if (!mounted) return;
      Navigator.pop(context); 
      Navigator.push(context, MaterialPageRoute(builder: (c) => ProfileScreen(userData: data)));
    } catch(e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to load profile")));
    }
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Select Language"),
        children: [
          SimpleDialogOption(
            onPressed: () {
              context.setLocale(const Locale('en'));
              Navigator.pop(context);
            },
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("English 🇺🇸"),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              context.setLocale(const Locale('si'));
              Navigator.pop(context);
            },
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Sinhala (සිංහල) 🇱🇰"),
            ),
          ),
        ],
      )
    );
  }
}
