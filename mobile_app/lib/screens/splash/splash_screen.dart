import 'package:flutter/material.dart';
import 'dart:async'; 
import '../auth/login_screen.dart'; 
import '../driver/driver_home_screen.dart';
import '../police/police_home_screen.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../widgets/biometric_prompt_screen.dart';
import '../../config/app_constants.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService      _authService      = AuthService();
  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _checkInitialSession();
  }

  Future<void> _checkInitialSession() async {
    // Wait for 3 seconds to let splash animation/logo be visible
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    try {
      // 1. Check if biometric is enabled first
      final biometricEnabled = await _biometricService.isBiometricEnabled();

      if (!mounted) return;

      if (biometricEnabled) {
        // Biometric ON → show full-screen biometric prompt (auto-triggers)
        // We do not need to check session first, BiometricPromptScreen will do that
        // after successful local authentication.
        debugPrint('[SplashScreen] Biometric enabled → BiometricPromptScreen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const BiometricPromptScreen(),
          ),
        );
        return;
      }

      // 2. Biometric OFF → check session to route to Home or Login
      final role = await _authService.checkSession();

      if (!mounted) return;

      if (role != null) {
        debugPrint('[SplashScreen] Session valid + biometric disabled → Home');
        _navigateToHome(role);
      } else {
        debugPrint('[SplashScreen] No active session → LoginScreen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      debugPrint('[SplashScreen] Error verifying session: $e');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     
      backgroundColor: AppColors.primaryGreen,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/app_icon/app_logo_circle.png',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 24), 

            
            const Text(
              'e-Fine SL',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.cardWhite, 
              ),
            ),
            const SizedBox(height: 48),

        
            const CircularProgressIndicator(
              color: AppColors.cardWhite,
            ),
          ],
        ),
      ),
    );
  }
}