import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../providers/theme_provider.dart';
import '../../config/app_constants.dart';
import '../auth/login_screen.dart';

class PoliceSettingsScreen extends StatefulWidget {
  const PoliceSettingsScreen({super.key});

  @override
  State<PoliceSettingsScreen> createState() => _PoliceSettingsScreenState();
}

class _PoliceSettingsScreenState extends State<PoliceSettingsScreen> {
  final AuthService      _authService      = AuthService();
  final BiometricService _biometricService = BiometricService();
  Map<String, dynamic>? _userData;
  bool _isLoading         = true;
  bool _biometricEnabled  = false;
  bool _biometricSupported = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
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

                  // --- SECURITY SECTION ---
                  Text(
                    'Security',
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
                            Icons.fingerprint,
                            color: !_biometricSupported
                                ? Colors.grey
                                : _biometricEnabled
                                    ? AppColors.primaryGreen
                                    : Colors.grey,
                          ),
                          title: Text(
                            'Fingerprint Login',
                            style: TextStyle(
                              color: _biometricSupported ? null : Colors.grey,
                            ),
                          ),
                          subtitle: Text(
                            !_biometricSupported
                                ? 'Not supported on this device'
                                : _biometricEnabled
                                    ? 'Tap to disable fingerprint login'
                                    : 'Enable quick fingerprint login',
                          ),
                          value: _biometricEnabled,
                          onChanged: _biometricSupported ? _handleBiometricToggle : null,
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

  // ── Biometric toggle handler ───────────────────────────────────────────

  Future<void> _handleBiometricToggle(bool val) async {
    if (val) {
      await _showBiometricCredentialSheet();
    } else {
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
                    const Icon(Icons.fingerprint, size: 36, color: AppColors.primaryBlue),
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
                          backgroundColor: AppColors.primaryBlue,
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
