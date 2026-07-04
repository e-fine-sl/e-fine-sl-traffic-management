// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/auth/email_verification_screen.dart
// Driver email OTP verification screen for e-Fine SL
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/app_constants.dart';
import '../../services/auth_service.dart';
import '../../widgets/otp_input_field.dart';

class EmailVerificationScreen extends StatefulWidget {
  /// The email address to verify
  final String email;

  /// Called when email is successfully verified
  final VoidCallback onVerified;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.onVerified,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final GlobalKey<OtpInputFieldState> _otpKey = GlobalKey<OtpInputFieldState>();

  bool _isVerifying = false;
  bool _isSendingOtp = false;
  bool _otpSent = false;
  String? _errorText;

  // Resend cooldown
  int _resendCooldown = 0;
  Timer? _resendTimer;

  // Envelope animation
  late AnimationController _animController;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bounceAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();

    // Automatically send OTP when screen opens
    _sendOtp();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  // ── Mask email: abc***@gmail.com ─────────────────────────────────────────
  String get _maskedEmail {
    final parts = widget.email.split('@');
    if (parts.length != 2) return widget.email;
    final local = parts[0];
    final domain = parts[1];
    final masked = local.length <= 3
        ? '${local[0]}***'
        : '${local.substring(0, 3)}***';
    return '$masked@$domain';
  }

  // ── Send OTP ────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    setState(() {
      _isSendingOtp = true;
      _errorText = null;
    });

    try {
      await _authService.sendDriverEmailOTP(widget.email);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _isSendingOtp = false;
      });
      _startResendCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── Start 60-second resend cooldown ─────────────────────────────────────
  void _startResendCooldown() {
    _resendCooldown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  // ── Verify OTP ──────────────────────────────────────────────────────────
  Future<void> _verifyOtp(String otp) async {
    if (otp.length < 6) {
      setState(() => _errorText = 'Please enter the complete 6-digit code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    try {
      await _authService.verifyDriverEmailOTP(widget.email, otp);
      if (!mounted) return;

      // Success! Show brief feedback then proceed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verified successfully! ✅'),
          backgroundColor: AppColors.successGreen,
          duration: Duration(seconds: 1),
        ),
      );

      // Slight delay so the user sees the success state
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      widget.onVerified();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });
      // Clear OTP fields on error so user can retry
      _otpKey.currentState?.clear();
    }
  }

  // ── Resend OTP ──────────────────────────────────────────────────────────
  Future<void> _resendOtp() async {
    if (_resendCooldown > 0) return;
    _otpKey.currentState?.clear();
    await _sendOtp();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primaryGreenDark,
            ),
      ),
      child: Scaffold(
        backgroundColor: isDark ? null : const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('Email Verification'),
          backgroundColor: AppColors.primaryGreenDark,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ScaleTransition(
              scale: _bounceAnim,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Envelope + Key Icon ───────────────────────────
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mark_email_read_rounded,
                            size: 44,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreenDark,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.vpn_key_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Title ─────────────────────────────────────────
                    Text(
                      'Verify Your Email Address',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── Subtitle ──────────────────────────────────────
                    Text(
                      _otpSent
                          ? 'We\'ve sent a 6-digit verification code to\n$_maskedEmail.\nPlease enter it below.'
                          : 'Sending verification code to\n$_maskedEmail...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Loading indicator while sending ───────────────
                    if (_isSendingOtp) ...[
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sending code...',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── OTP Input Field ───────────────────────────────
                    if (_otpSent) ...[
                      OtpInputField(
                        key: _otpKey,
                        length: 6,
                        accentColor: AppColors.primaryGreen,
                        filledBackground: AppColors.pastelGreen,
                        onCompleted: _verifyOtp,
                      ),

                      const SizedBox(height: 16),

                      // ── Error text ──────────────────────────────────
                      if (_errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.errorRed, size: 16),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _errorText!,
                                  style: const TextStyle(
                                    color: AppColors.errorRed,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 8),

                      // ── Verify Button ───────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isVerifying
                              ? null
                              : () => _verifyOtp(
                                  _otpKey.currentState?.currentOtp ?? ''),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          child: _isVerifying
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Verify Email',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ── Resend Code ─────────────────────────────────
                      GestureDetector(
                        onTap: _resendCooldown > 0 ? null : _resendOtp,
                        child: Text.rich(
                          TextSpan(
                            text: 'Didn\'t receive the code?  ',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white60
                                  : AppColors.textSecondary,
                            ),
                            children: [
                              TextSpan(
                                text: _resendCooldown > 0
                                    ? 'Resend in ${_resendCooldown}s'
                                    : 'Resend Code',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _resendCooldown > 0
                                      ? (isDark
                                          ? Colors.white38
                                          : AppColors.textHint)
                                      : AppColors.primaryGreenDark,
                                  decoration: _resendCooldown > 0
                                      ? null
                                      : TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
