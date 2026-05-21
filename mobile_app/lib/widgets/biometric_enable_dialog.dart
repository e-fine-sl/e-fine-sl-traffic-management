// ─────────────────────────────────────────────────────────────────────────────
// lib/widgets/biometric_enable_dialog.dart
// e-Fine SL — Custom "Enable Biometric Login?" Dialog Widget
//
// Shown after a successful first-time credential login.
// Accepts onEnable() and onSkip() callbacks.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../config/app_constants.dart';

class BiometricEnableDialog extends StatelessWidget {
  /// Called when the user confirms they want to enable biometrics.
  final VoidCallback onEnable;

  /// Called when the user dismisses the dialog without enabling.
  final VoidCallback onSkip;

  const BiometricEnableDialog({
    super.key,
    required this.onEnable,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Gradient Header ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                    : [AppColors.primaryGreen, AppColors.primaryGreenDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                // Fingerprint icon with animated ring
                _AnimatedFingerprintIcon(),
                const SizedBox(height: 12),
                const Text(
                  'Quick & Secure Login',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Column(
              children: [
                Text(
                  'Enable Fingerprint Login?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Skip typing your password every time.\n'
                  'Your fingerprint unlocks the app instantly.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary(context),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                // Feature pills
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    _FeaturePill(icon: Icons.lock_outline,      label: 'Encrypted'),
                    _FeaturePill(icon: Icons.flash_on_outlined, label: 'Instant'),
                    _FeaturePill(icon: Icons.shield_outlined,   label: 'Secure'),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Enable Button ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: onEnable,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.fingerprint, size: 22),
                    label: const Text(
                      'Enable Fingerprint Login',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Skip Button ────────────────────────────────────────────
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    'Maybe Later',
                    style: TextStyle(
                      color: AppTheme.textSecondary(context),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated Fingerprint Icon ──────────────────────────────────────────────────

class _AnimatedFingerprintIcon extends StatefulWidget {
  @override
  State<_AnimatedFingerprintIcon> createState() => _AnimatedFingerprintIconState();
}

class _AnimatedFingerprintIconState extends State<_AnimatedFingerprintIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.fingerprint,
          size: 52,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Feature Pill Widget ────────────────────────────────────────────────────────

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String   label;

  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryGreen),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
