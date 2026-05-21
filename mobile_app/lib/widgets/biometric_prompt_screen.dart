// ─────────────────────────────────────────────────────────────────────────────
// lib/widgets/biometric_prompt_screen.dart
// e-Fine SL — Full-Screen Biometric Authentication Prompt
//
// Shown on app launch when biometric is enabled and session is valid.
// On success  → navigates to the correct Home screen.
// On cancel   → falls back to LoginScreen.
// On expiry   → calls _handleSessionExpired and navigates to LoginScreen.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../config/app_constants.dart';
import '../services/biometric_service.dart';
import '../services/auth_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/driver/driver_home_screen.dart';
import '../screens/police/police_home_screen.dart';

class BiometricPromptScreen extends StatefulWidget {
  /// The user's role, read from secure storage on splash screen.
  /// Determines which home screen to navigate to on success.
  final String? knownRole;

  const BiometricPromptScreen({super.key, this.knownRole});

  @override
  State<BiometricPromptScreen> createState() => _BiometricPromptScreenState();
}

class _BiometricPromptScreenState extends State<BiometricPromptScreen>
    with SingleTickerProviderStateMixin {
  final BiometricService _biometricService = BiometricService();
  final AuthService      _authService      = AuthService();

  late AnimationController _pulseController;
  late Animation<double>   _pulseAnim;

  bool _isAuthenticating = false;
  bool _authFailed       = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Setup pulse animation for the fingerprint icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.90, end: 1.10).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-trigger biometric prompt after a short delay so the UI is visible first
    Future.delayed(const Duration(milliseconds: 600), _triggerBiometric);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AUTHENTICATION LOGIC
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _triggerBiometric() async {
    if (!mounted) return;
    setState(() {
      _isAuthenticating = true;
      _authFailed       = false;
      _errorMessage     = null;
    });

    // Step 1: Show OS biometric prompt
    final authenticated = await _biometricService.authenticate(
      reason: 'Verify your identity to log in to e-Fine SL',
    );

    if (!mounted) return;

    if (!authenticated) {
      setState(() {
        _isAuthenticating = false;
        _authFailed       = true;
        _errorMessage     = 'Biometric not recognised. Try again or use password.';
      });
      return;
    }

    // Step 2: Check if session is still valid
    final role = await _authService.checkSession();

    if (!mounted) return;

    if (role != null) {
      // Session valid — biometric just verified identity locally, go to Home
      _navigateToHome(role);
    } else {
      // Session expired — perform a full re-login with stored credentials
      await _handleSessionExpiredBiometricLogin();
    }
  }

  Future<void> _handleSessionExpiredBiometricLogin() async {
    if (!mounted) return;
    setState(() => _isAuthenticating = true);

    try {
      final userData = await _biometricService.loginWithBiometric();
      if (!mounted) return;
      final role = userData['role'] as String? ?? UserRoles.driver;
      _navigateToHome(role);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _authFailed       = true;
        _errorMessage     = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _navigateToHome(String role) {
    if (role == UserRoles.officer || role == UserRoles.admin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PoliceHomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
      );
    }
  }

  void _usePasswordInstead() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo
                Image.asset(
                  AppAssets.logoCircle,
                  height: 80,
                ),
                const SizedBox(height: 12),
                Text(
                  'e-Fine SL',
                  style: TextStyle(
                    fontSize: 20,
                    color: AppTheme.textSecondary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 48),

                // Animated fingerprint icon
                ScaleTransition(
                  scale: _pulseAnim,
                  child: GestureDetector(
                    onTap: _isAuthenticating ? null : _triggerBiometric,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: _authFailed
                              ? [
                                  AppColors.errorRed.withValues(alpha: 0.15),
                                  AppColors.errorRed.withValues(alpha: 0.05),
                                ]
                              : [
                                  AppColors.primaryGreen.withValues(alpha: 0.15),
                                  AppColors.primaryGreen.withValues(alpha: 0.05),
                                ],
                        ),
                        border: Border.all(
                          color: _authFailed
                              ? AppColors.errorRed.withValues(alpha: 0.4)
                              : AppColors.primaryGreen.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: _isAuthenticating
                          ? Padding(
                              padding: const EdgeInsets.all(28.0),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.primaryGreen,
                              ),
                            )
                          : Icon(
                              Icons.fingerprint,
                              size: 68,
                              color: _authFailed
                                  ? AppColors.errorRed
                                  : AppColors.primaryGreen,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Status text
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isAuthenticating
                      ? Text(
                          'Authenticating...',
                          key: const ValueKey('auth'),
                          style: TextStyle(
                            color: AppTheme.textSecondary(context),
                            fontSize: 15,
                          ),
                        )
                      : _authFailed
                          ? Column(
                              key: const ValueKey('fail'),
                              children: [
                                Text(
                                  _errorMessage ?? 'Authentication failed',
                                  style: const TextStyle(
                                    color: AppColors.errorRed,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _triggerBiometric,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Try Again'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primaryGreen,
                                    side: const BorderSide(color: AppColors.primaryGreen),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Touch the fingerprint sensor to continue',
                              key: const ValueKey('idle'),
                              style: TextStyle(
                                color: AppTheme.textSecondary(context),
                                fontSize: 15,
                              ),
                              textAlign: TextAlign.center,
                            ),
                ),

                const SizedBox(height: 40),

                // Use Password Instead
                TextButton.icon(
                  onPressed: _usePasswordInstead,
                  icon: Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: AppTheme.textSecondary(context),
                  ),
                  label: Text(
                    'Use Password Instead',
                    style: TextStyle(
                      color: AppTheme.textSecondary(context),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
