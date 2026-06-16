import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import '../../config/app_constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      "image": "assets/images/onboarding_1.png",
      "title": "Track Traffic Fines",
      "description": "Instantly view and manage your traffic fines digitally with absolute clarity and peace of mind."
    },
    {
      "image": "assets/images/onboarding_2.png",
      "title": "Secure Digital Payments",
      "description": "Pay your fines securely and safely. Keep a complete track of your payment history in one convenient place."
    },
    {
      "image": "assets/images/onboarding_3.png",
      "title": "Public Accident Reporting",
      "description": "Instantly report accidents to the traffic police with our streamlined public reporting tool."
    },
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 10,
      width: _currentPage == index ? 24 : 10,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _currentPage == index ? AppColors.primaryGreen : Colors.grey.shade300,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text(
                  'Skip',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            
            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (value) {
                  setState(() {
                    _currentPage = value;
                  });
                },
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          _onboardingData[index]["image"]!,
                          height: 350,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 50),
                        Text(
                          _onboardingData[index]["title"]!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _onboardingData[index]["description"]!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 15,
                            height: 1.5,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Bottom Controls
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dots
                  Row(
                    children: List.generate(
                      _onboardingData.length,
                      (index) => _buildDot(index),
                    ),
                  ),
                  
                  // Next / Get Started Button
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _onboardingData.length - 1) {
                        _completeOnboarding();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),
                    child: Text(
                      _currentPage == _onboardingData.length - 1
                          ? 'Get Started'
                          : 'Next',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
