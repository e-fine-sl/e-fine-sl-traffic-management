import 'package:flutter/material.dart';
import 'package:mobile_app/services/auth_service.dart';
import 'package:mobile_app/services/biometric_service.dart';
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
  final AuthService      _authService      = AuthService();
  final BiometricService _biometricService = BiometricService();
  bool _notificationsEnabled  = true;
  bool _biometricEnabled      = false;
  bool _biometricSupported    = false;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = NotificationService().isEnabled;
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final supported = await _biometricService.isDeviceSupported();
    final enabled   = await _biometricService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricSupported = supported;
        _biometricEnabled   = enabled;
      });
    }
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Section 1: Account
          _buildSectionHeader("Account"),
          _buildListTile(
            icon: Icons.person_outline, 
            title: "Profile", 
            subtitle: "View and edit your profile",
            onTap: _navigateToProfile,
          ),

          const Divider(indent: 24, endIndent: 24),

          // Section 2: Appearance
          _buildSectionHeader("Appearance"),
          // Dark Mode
          _buildSwitchListTile(
            icon: Icons.dark_mode_outlined,
            title: "Dark Mode",
            value: isDark,
            onChanged: (val) {
              context.read<ThemeProvider>().toggleTheme(val);
            },
          ),
          // Language
          _buildListTile(
            icon: Icons.language, 
            title: "Language", 
            subtitle: context.locale.languageCode == 'en' ? "English" : "Sinhala (සිංහල)",
            onTap: _showLanguageDialog
          ),

          const Divider(indent: 24, endIndent: 24),

          // Section 3: Security
          _buildSectionHeader("Security"),
          _buildSwitchListTile(
            icon: Icons.fingerprint,
            title: "Fingerprint Login",
            subtitle: !_biometricSupported
                ? "Not supported on this device"
                : _biometricEnabled
                    ? "Tap to disable fingerprint login"
                    : "Enable quick fingerprint login",
            value: _biometricEnabled,
            enabled: _biometricSupported,
            onChanged: _biometricSupported ? _handleBiometricToggle : null,
          ),

          const Divider(indent: 24, endIndent: 24),

          // Section 4: General
          _buildSectionHeader("General"),
          _buildSwitchListTile(
            icon: Icons.notifications_outlined,
            title: "Notifications",
            subtitle: _notificationsEnabled
                ? "Show fines in device notification bar"
                : "Device notifications disabled",
            value: _notificationsEnabled,
            onChanged: _toggleNotifications,
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

          const Divider(indent: 24, endIndent: 24),

          // Section 4: Logout
          const SizedBox(height: 20),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.logout, color: AppColors.errorRed, size: 24),
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
      padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).hintColor, 
          fontWeight: FontWeight.bold, 
          fontSize: 11,
          letterSpacing: 1.1,
        )
      ),
    );
  }

  Widget _buildListTile({required IconData icon, required String title, String? subtitle, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.1), 
          borderRadius: BorderRadius.circular(8)
        ),
        child: Icon(icon, color: AppColors.primaryGreen, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSwitchListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    bool enabled = true,
    required ValueChanged<bool>? onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: enabled ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(8)
        ),
        child: Icon(icon, color: enabled ? AppColors.primaryGreen : Colors.grey, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: enabled ? null : Colors.grey,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.primaryGreen,
        inactiveThumbColor: Colors.grey[300],
        inactiveTrackColor: Colors.grey[400],
      ),
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

  // ── Biometric toggle handler ───────────────────────────────────────────

  Future<void> _handleBiometricToggle(bool val) async {
    if (val) {
      // Enabling → ask user to confirm credentials
      await _showBiometricCredentialSheet();
    } else {
      // Disabling → just clear the biometric keys
      await _biometricService.disableBiometric();
      if (mounted) {
        setState(() => _biometricEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fingerprint login disabled'),
            backgroundColor: AppColors.warningOrange,
          ),
        );
      }
    }
  }

  Future<void> _showBiometricCredentialSheet() async {
    final emailCtrl    = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool  obscure      = true;
    bool  isLoading    = false;
    String? error;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Icon(Icons.fingerprint, size: 36, color: AppColors.primaryGreen),
                    const SizedBox(height: 8),
                    const Text(
                      'Confirm to Enable Fingerprint',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter your credentials to set up fingerprint login',
                      style: TextStyle(color: AppTheme.textSecondary(ctx), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined),
                        hintText: 'Email Address',
                        filled: true,
                        fillColor: AppTheme.inputFill(ctx),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setSheetState(() => obscure = !obscure),
                        ),
                        hintText: 'Password',
                        filled: true,
                        fillColor: AppTheme.inputFill(ctx),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        errorText: error,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
                                  setSheetState(() => error = 'Please fill in all fields');
                                  return;
                                }
                                setSheetState(() { isLoading = true; error = null; });
                                try {
                                  await _biometricService.enableBiometric(
                                    email:    emailCtrl.text.trim(),
                                    password: passwordCtrl.text,
                                  );
                                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                                  if (mounted) {
                                    setState(() => _biometricEnabled = true);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✓ Fingerprint login enabled!'),
                                        backgroundColor: AppColors.successGreen,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setSheetState(() {
                                    isLoading = false;
                                    error = e.toString().replaceAll('Exception: ', '');
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 22, width: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('Enable Fingerprint Login', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary(ctx))),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
