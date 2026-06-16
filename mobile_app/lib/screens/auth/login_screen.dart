import 'package:flutter/material.dart';
import 'package:mobile_app/screens/auth/forgot_password_screen.dart';
import 'package:mobile_app/screens/auth/user_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../widgets/biometric_enable_dialog.dart';
import '../../widgets/biometric_prompt_screen.dart';
import '../driver/driver_home_screen.dart';
import '../police/police_home_screen.dart';
import '../../config/app_constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService      _authService      = AuthService();
  final BiometricService _biometricService = BiometricService();

  // Controllers
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isObscure           = true;
  bool _isLoading           = false;
  bool _showBiometricButton = false; // Shown only if biometric is enabled

  @override
  void initState() {
    super.initState();
    _checkBiometricState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Check if biometric is enabled to decide whether to show the fingerprint icon.
  Future<void> _checkBiometricState() async {
    final enabled = await _biometricService.isBiometricEnabled();
    if (mounted) {
      setState(() => _showBiometricButton = enabled);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.errorRed),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREDENTIAL LOGIN
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Please enter email and password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userData = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      final role = userData['role'] as String? ?? UserRoles.driver;

      // ── Check if we should show the "Enable Biometric?" dialog ──────────
      await _maybeShowBiometricDialog(
        role: role,
        enteredEmail: _emailController.text.trim(),
        enteredPassword: _passwordController.text,
      );

    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POST-LOGIN BIOMETRIC DIALOG LOGIC
  // ─────────────────────────────────────────────────────────────────────────

  /// Shows the "Enable Biometric?" dialog if this is the first time the user
  /// logs in (fresh install or after session expiry).
  Future<void> _maybeShowBiometricDialog({
    required String role,
    required String enteredEmail,
    required String enteredPassword,
  }) async {
    if (!mounted) return;

    // Check if device supports biometrics at all
    final deviceSupported = await _biometricService.isDeviceSupported();
    if (!deviceSupported) {
      // No biometric hardware — go straight to home
      _navigateToHome(role);
      return;
    }

    // Check the dialog-shown flag in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final dialogShown = prefs.getBool(PrefKeys.biometricDialogShown) ?? false;

    if (!mounted) return;

    if (dialogShown) {
      // Dialog was already shown before (and user made a choice) — skip
      _navigateToHome(role);
      return;
    }

    // Mark dialog as shown immediately (so it won't re-appear on next manual re-login)
    await prefs.setBool(PrefKeys.biometricDialogShown, true);

    if (!mounted) return;

    // Show the custom dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BiometricEnableDialog(
        onEnable: () {
          Navigator.of(context).pop(); // Close dialog
          _showCredentialConfirmation(
            role: role,
            enteredEmail: enteredEmail,
            enteredPassword: enteredPassword,
          );
        },
        onSkip: () {
          Navigator.of(context).pop(); // Close dialog
          _navigateToHome(role);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREDENTIAL CONFIRMATION (before enabling biometric)
  // ─────────────────────────────────────────────────────────────────────────

  /// Shows a bottom-sheet asking the user to re-enter credentials to confirm
  /// before enabling biometric. Uses the credentials already entered (pre-fills
  /// the email field) to reduce friction.
  Future<void> _showCredentialConfirmation({
    required String role,
    required String enteredEmail,
    required String enteredPassword,
  }) async {
    final confirmEmailCtrl    = TextEditingController(text: enteredEmail);
    final confirmPasswordCtrl = TextEditingController();
    bool  confirmObscure      = true;
    bool  isConfirming        = false;
    String? confirmError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Icon(Icons.fingerprint, size: 36, color: AppColors.primaryGreen),
                    const SizedBox(height: 8),

                    const Text(
                      'Confirm Your Identity',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter your password to enable fingerprint login',
                      style: TextStyle(color: AppTheme.textSecondary(ctx), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Email field (pre-filled, read-only)
                    TextField(
                      controller: confirmEmailCtrl,
                      readOnly: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined),
                        hintText: 'Email',
                        filled: true,
                        fillColor: AppTheme.inputFill(ctx),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Password field
                    TextField(
                      controller: confirmPasswordCtrl,
                      obscureText: confirmObscure,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(confirmObscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setSheetState(() => confirmObscure = !confirmObscure),
                        ),
                        hintText: 'Password',
                        filled: true,
                        fillColor: AppTheme.inputFill(ctx),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        errorText: confirmError,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isConfirming
                            ? null
                            : () async {
                                if (confirmPasswordCtrl.text.isEmpty) {
                                  setSheetState(() => confirmError = 'Please enter your password');
                                  return;
                                }
                                setSheetState(() {
                                  isConfirming  = true;
                                  confirmError  = null;
                                });
                                try {
                                  await _biometricService.enableBiometric(
                                    email:    confirmEmailCtrl.text.trim(),
                                    password: confirmPasswordCtrl.text,
                                  );
                                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop(true);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✓ Fingerprint login enabled!'),
                                        backgroundColor: AppColors.successGreen,
                                      ),
                                    );
                                    setState(() => _showBiometricButton = true);
                                  }
                                  _navigateToHome(role);
                                } catch (e) {
                                  setSheetState(() {
                                    isConfirming = false;
                                    confirmError = e.toString().replaceAll('Exception: ', '');
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: isConfirming
                            ? const SizedBox(
                                height: 22,
                                width:  22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                'Enable Fingerprint Login',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextButton(
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        _navigateToHome(role);
                      },
                      child: Text('Skip', style: TextStyle(color: AppTheme.textSecondary(ctx))),
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

  // ─────────────────────────────────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────────────────────────────────

  void _navigateToHome(String role) {
    if (!mounted) return;
    if (role == UserRoles.officer || role == UserRoles.admin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PoliceHomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: AppColors.primaryGreen,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: AppColors.primaryGreen,
        ),
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/login_bg.png'),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/icons/app_icon/app_logo_circle.png',
                    height: 100,
                  ),
                const SizedBox(height: 10),
                
                Text(
                  'E-Fine SL',
                  style: GoogleFonts.montserrat(
                    fontSize: 32, 
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    shadows: const [Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                ),
                const SizedBox(height: 30),
  
                const Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 3))],
                  ),
                ),
                const SizedBox(height: 40),
  
                // Email Input
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_outlined),
                    hintText: 'Email Address',
                    filled: true,
                    fillColor: AppTheme.inputFill(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
  
                // Password Input
                TextField(
                  controller: _passwordController,
                  obscureText: _isObscure,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                    ),
                    hintText: 'Password',
                    filled: true,
                    fillColor: AppTheme.inputFill(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
  
                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'LOGIN',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Biometric Login Button (shown only when enabled) ───────
                if (_showBiometricButton) ...[
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const BiometricPromptScreen()),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                            ],
                          ),
                          child: const Icon(
                            Icons.fingerprint,
                            size: 38,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Login with Fingerprint',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2))],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                    );
                  },
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                  ),
                ),
  
                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UserSelectionScreen()),
                        );
                      },
                      child: const Text(
                        'Register Here',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlueLight,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}