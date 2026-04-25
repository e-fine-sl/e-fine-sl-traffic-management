// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/auth/license_recovery_screen.dart
// e-Fine SL — Driver Account Recovery via Driving License
//
// Flow:
//   Step 1 → Enter Driving License Number → lookup driver (masked info shown)
//   Step 2 → Scan front side of physical license → OCR extracts license number
//   Step 3 → Server verifies scanned vs entered → issues 10-min recovery token
//   Step 4 → Enter new password twice → RSA-encrypted → reset
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../config/app_constants.dart';
import '../../services/auth_service.dart';

// ── Step Enum ─────────────────────────────────────────────────────────────────
enum _RecoveryStep { lookup, scan, verifying, setPassword }

class LicenseRecoveryScreen extends StatefulWidget {
  const LicenseRecoveryScreen({super.key});

  @override
  State<LicenseRecoveryScreen> createState() => _LicenseRecoveryScreenState();
}

class _LicenseRecoveryScreenState extends State<LicenseRecoveryScreen>
    with SingleTickerProviderStateMixin {

  final AuthService _authService = AuthService();

  _RecoveryStep _step = _RecoveryStep.lookup;
  bool _isLoading = false;

  // Step 1
  final _licenseController = TextEditingController();
  String _driverName       = '';
  String _maskedEmail      = '';
  String _confirmedLicense = '';

  // Step 2
  DocumentScanner? _scanner;
  File?   _scannedFile;
  String  _scannedLicenseNumber = '';
  bool    _isScanning           = false;
  String  _scanStatus           = '';

  // Step 3
  String  _recoveryToken = '';

  // Step 4
  final _passController        = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _obscurePass    = true;
  bool _obscureConfirm = true;

  // Animation
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _scanner = DocumentScanner(
      options: DocumentScannerOptions(
        mode: ScannerMode.filter,
        pageLimit: 1,
        isGalleryImport: true,
      ),
    );
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _licenseController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    _scanner?.close();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _goToStep(_RecoveryStep step) {
    setState(() => _step = step);
    _fadeCtrl.forward(from: 0);
  }

  // ── Step 1: Lookup driver ────────────────────────────────────────────────────

  Future<void> _lookupDriver() async {
    final license = _licenseController.text.trim();
    if (license.isEmpty) {
      _showError('Please enter your Driving License Number.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await _authService.lookupDriverByLicense(license);
      setState(() {
        _driverName       = data['name'] as String? ?? '';
        _maskedEmail      = data['maskedEmail'] as String? ?? '';
        _confirmedLicense = data['licenseNumber'] as String? ?? license;
      });
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Step 2: Scan license front ───────────────────────────────────────────────

  Future<void> _scanLicense() async {
    setState(() {
      _isScanning = true;
      _scanStatus = 'Opening scanner…';
      _scannedFile = null;
      _scannedLicenseNumber = '';
    });
    try {
      final result = await _scanner?.scanDocument();
      if (result == null || result.images == null || result.images!.isEmpty) {
        setState(() { _isScanning = false; _scanStatus = ''; });
        return;
      }
      final imagePath = result.images!.first;
      setState(() {
        _scannedFile = File(imagePath);
        _scanStatus  = 'Extracting license number…';
      });
      await _runOCR(imagePath);
    } catch (e) {
      if (!e.toString().contains('Canceled by user')) {
        _showError('Scanner error: $e');
      }
      setState(() { _isScanning = false; _scanStatus = ''; });
    }
  }

  // ── OCR — extract license number from front side ──────────────────────────

  Future<void> _runOCR(String imagePath) async {
    final inputImage    = InputImage.fromFilePath(imagePath);
    final recognizer    = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText recognised = await recognizer.processImage(inputImage);
      final text = recognised.text;

      // Strategy 1: Field-5 label (e.g. "5. B1234567")
      String raw = '';
      final labelMatch = RegExp(r'5[.\s]+([A-Z0-9\s.\-]+)').firstMatch(text);
      if (labelMatch != null) raw = labelMatch.group(1) ?? '';

      // Strategy 2: Sri Lankan license pattern [Letter][7 digits]
      if (raw.isEmpty) {
        final patternMatch = RegExp(r'[A-Z]\d{7}').firstMatch(text.replaceAll(RegExp(r'\s+'), ''));
        raw = patternMatch?.group(0) ?? '';
      }

      // Strategy 3: 8-digit sequence fallback
      if (raw.isEmpty) {
        final digitMatch = RegExp(r'\b\d{8}\b').firstMatch(text.replaceAll(RegExp(r'\s+'), ''));
        raw = digitMatch?.group(0) ?? '';
      }

      // Clean and cap at 8 chars
      String clean = raw.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (clean.length > 8 && RegExp(r'^[A-Z]').hasMatch(clean)) {
        clean = clean.substring(0, 8);
      }

      setState(() {
        _scannedLicenseNumber = clean;
        _isScanning = false;
        _scanStatus = '';
      });
    } catch (e) {
      setState(() { _isScanning = false; _scanStatus = ''; });
      _showError('OCR failed: $e');
    } finally {
      recognizer.close();
    }
  }

  // ── Step 3: Verify scan with backend ────────────────────────────────────────

  Future<void> _verifyWithBackend() async {
    if (_scannedLicenseNumber.isEmpty) {
      _showError('No license number was extracted. Please scan again.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final token = await _authService.verifyLicenseScan(
        _confirmedLicense,
        _scannedLicenseNumber,
      );
      setState(() => _recoveryToken = token);
      _showSuccess('License verified! Please set your new password.');
      _goToStep(_RecoveryStep.setPassword);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Step 4: Reset password ───────────────────────────────────────────────────

  Future<void> _resetPassword() async {
    final pass    = _passController.text;
    final confirm = _confirmPassController.text;
    if (pass.length < 8) {
      _showError('Password must be at least 8 characters.');
      return;
    }
    if (pass != confirm) {
      _showError('Passwords do not match.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.resetPasswordByLicense(_confirmedLicense, _recoveryToken, pass);
      _showSuccess('Password reset successfully! Please log in.');
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recover via License ID'),
        backgroundColor: AppColors.primaryGreenDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStepIndicator(),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildCurrentStep(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step indicator ────────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    const labels = ['Find Account', 'Scan License', 'Verify', 'New Password'];
    final current = _step.index;
    return Row(
      children: List.generate(labels.length, (i) {
        final done    = i < current;
        final active  = i == current;
        final color   = done || active ? AppColors.primaryGreen : AppColors.textHint;
        return Expanded(
          child: Column(
            children: [
              Row(children: [
                if (i > 0) Expanded(child: Container(height: 2, color: done ? AppColors.primaryGreen : AppColors.divider)),
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primaryGreen : (done ? AppColors.primaryGreenLight : AppColors.divider),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: done
                      ? const Icon(Icons.check, size: 16, color: AppColors.primaryGreenDark)
                      : Text('${i+1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: active ? Colors.white : AppColors.textSecondary)),
                  ),
                ),
                if (i < labels.length - 1) Expanded(child: Container(height: 2, color: done ? AppColors.primaryGreen : AppColors.divider)),
              ]),
              const SizedBox(height: 4),
              Text(labels[i], style: TextStyle(fontSize: 10, color: color, fontWeight: active ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case _RecoveryStep.lookup:      return _buildLookupStep();
      case _RecoveryStep.scan:        return _buildScanStep();
      case _RecoveryStep.verifying:   return _buildScanStep(); // same UI, verify button active
      case _RecoveryStep.setPassword: return _buildPasswordStep();
    }
  }

  // ── Step 1 UI ─────────────────────────────────────────────────────────────────

  Widget _buildLookupStep() {
    return Column(
      key: const ValueKey('lookup'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoCard(
          icon: Icons.credit_card_outlined,
          title: 'Enter Your License Number',
          subtitle: 'This is the Driving License Number you used when registering your driver account.',
          color: AppColors.primaryGreen,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _licenseController,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.badge_outlined),
            hintText: 'e.g.  B1234567',
            filled: true,
            fillColor: AppTheme.inputFill(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 20),
        _primaryButton(label: 'Find My Account', icon: Icons.search, onTap: _isLoading ? null : _lookupDriver),
        if (_driverName.isNotEmpty) ...[
          const SizedBox(height: 24),
          _driverConfirmCard(),
          const SizedBox(height: 16),
          _primaryButton(
            label: 'Yes, This Is Me — Continue',
            icon: Icons.arrow_forward,
            onTap: () => _goToStep(_RecoveryStep.scan),
          ),
        ],
      ],
    );
  }

  Widget _driverConfirmCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Account Found', style: TextStyle(color: AppColors.primaryGreenDark, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(_driverName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.email_outlined, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(_maskedEmail, style: const TextStyle(color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }

  // ── Step 2 UI ─────────────────────────────────────────────────────────────────

  Widget _buildScanStep() {
    final hasResult = _scannedLicenseNumber.isNotEmpty;
    return Column(
      key: const ValueKey('scan'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoCard(
          icon: Icons.document_scanner_outlined,
          title: 'Scan Your Physical License',
          subtitle: 'Place the FRONT side of your driving license within the frame. Ensure all text is clearly visible.',
          color: AppColors.primaryBlue,
        ),
        const SizedBox(height: 24),

        if (_scannedFile != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(_scannedFile!, height: 190, fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
        ],

        if (_isScanning) ...[
          const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
          const SizedBox(height: 8),
          Text(_scanStatus, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
        ],

        if (hasResult) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.infoBlueBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.qr_code_scanner, color: AppColors.primaryBlue, size: 20),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Scanned License Number', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(_scannedLicenseNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2, color: AppColors.primaryBlue)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        if (!_isScanning) ...[
          _primaryButton(
            label: hasResult ? 'Re-Scan License' : 'Scan Front Side',
            icon: Icons.document_scanner,
            onTap: _scanLicense,
            outline: hasResult,
          ),
          if (hasResult) ...[
            const SizedBox(height: 12),
            _primaryButton(
              label: _isLoading ? 'Verifying…' : 'Verify & Continue',
              icon: Icons.verified_outlined,
              onTap: _isLoading ? null : _verifyWithBackend,
            ),
          ],
        ],

        const SizedBox(height: 24),
        _tipBox('Make sure the front of your license is flat, well-lit, and all text is sharp and readable.'),
      ],
    );
  }

  // ── Step 4 UI ─────────────────────────────────────────────────────────────────

  Widget _buildPasswordStep() {
    final pass = _passController.text;
    final strength = pass.isEmpty ? 0 : (pass.length >= 12 && RegExp(r'[A-Z]').hasMatch(pass) && RegExp(r'[0-9]').hasMatch(pass) ? 3 : (pass.length >= 8 ? 2 : 1));
    final strengthColors = [Colors.transparent, AppColors.errorRed, AppColors.warningOrange, AppColors.successGreen];
    final strengthLabels = ['', 'Weak', 'Good', 'Strong'];

    return StatefulBuilder(
      key: const ValueKey('password'),
      builder: (context, setLocal) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _infoCard(
              icon: Icons.lock_reset_outlined,
              title: 'Set Your New Password',
              subtitle: 'Choose a strong password with at least 8 characters.',
              color: AppColors.primaryGreenDark,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passController,
              obscureText: _obscurePass,
              onChanged: (_) => setLocal(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline),
                hintText: 'New Password',
                filled: true,
                fillColor: AppTheme.inputFill(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Strength bar
            if (pass.isNotEmpty) ...[
              Row(children: [
                ...List.generate(3, (i) => Expanded(
                  child: Container(
                    height: 4, margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i < strength ? strengthColors[strength] : AppColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                )),
                const SizedBox(width: 8),
                Text(strengthLabels[strength], style: TextStyle(fontSize: 12, color: strengthColors[strength], fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPassController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline),
                hintText: 'Confirm New Password',
                filled: true,
                fillColor: AppTheme.inputFill(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _primaryButton(
              label: _isLoading ? 'Resetting…' : 'Reset Password',
              icon: Icons.check_circle_outline,
              onTap: _isLoading ? null : _resetPassword,
            ),
          ],
        );
      },
    );
  }

  // ── Shared Widgets ────────────────────────────────────────────────────────────

  Widget _infoCard({required IconData icon, required String title, required String subtitle, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.04)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
        ])),
      ]),
    );
  }

  Widget _primaryButton({required String label, required IconData icon, required VoidCallback? onTap, bool outline = false}) {
    return SizedBox(
      height: 52,
      child: outline
        ? OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(color: AppColors.primaryGreen),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          )
        : ElevatedButton.icon(
            onPressed: onTap,
            icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icon),
            label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 3,
            ),
          ),
    );
  }

  Widget _tipBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warningOrange.withValues(alpha: 0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.warningOrange),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4))),
      ]),
    );
  }
}
