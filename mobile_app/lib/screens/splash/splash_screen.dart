import 'package:flutter/material.dart';
import 'dart:async'; 
import '../auth/login_screen.dart'; 
import '../driver/driver_home_screen.dart';
import '../police/police_home_screen.dart';
import '../../services/auth_service.dart';
import '../../config/app_constants.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

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
      final role = await _authService.checkSession();

      if (!mounted) return;

      if (role != null) {
        if (role == UserRoles.officer || role == UserRoles.admin) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const PoliceHomeScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
          );
        }
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      debugPrint('[SplashScreen] Error verifying session: $e');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
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