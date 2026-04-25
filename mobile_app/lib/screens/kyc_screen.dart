// ─────────────────────────────────────────────────────────────────────────────
// lib/screens/kyc_screen.dart
// e-Fine SL — KYC Face + License OCR Verification Screen
//
// Multi-step flow:
//   Step 1 → Upload or capture driving license photo (front side)
//            + On-device OCR scans NIC & license number
//   Step 2 → Upload or capture driving license photo (back side)
//            + On-device OCR scans expiry dates and vehicle classes
//   Step 3 → Show scanned data — verify NIC & license number match registration
//   Step 4 → Liveness detection: Blink → Smile → Neutral → Capture
//   Result → Auto-complete after successful liveness (no backend API call)
//
// Usage:
//   Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (_) => KycScreen(
//         registeredNIC: '199012345678',
//         registeredLicenseNumber: 'B1234567',
//         onVerified: (issueDate, expiryDate, classes, profileImg, front, back) { },
//       ),
//     ),
//   );
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'dart:convert';
import '../../config/app_constants.dart';
import '../widgets/liveness_camera_view.dart';

// ─── KycScreen ───────────────────────────────────────────────────────────────

class KycScreen extends StatefulWidget {
  /// Called when the KYC verification succeeds. The caller should use this
  /// callback to proceed with the next step (e.g. final registration submit).
  final Future<void> Function(String issueDate, String expiryDate, List<Map<String, String>> vehicleClasses, String profileImageBase64, String licenseFrontBase64, String licenseBackBase64) onVerified;

  /// The NIC number entered during registration (used to verify OCR result).
  final String registeredNIC;

  /// The license number entered during registration (used to verify OCR result).
  final String registeredLicenseNumber;

  /// The issue date entered by the user during registration (dd/MM/yyyy).
  final String registeredIssueDate;

  /// The expiry date entered by the user during registration (dd/MM/yyyy).
  final String registeredExpiryDate;

  const KycScreen({
    super.key,
    required this.onVerified,
    required this.registeredNIC,
    required this.registeredLicenseNumber,
    required this.registeredIssueDate,
    required this.registeredExpiryDate,
  });

  @override
  State<KycScreen> createState() => _KycScreenState();
}

// ─── Step enum ───────────────────────────────────────────────────────────────

enum _KycStep { licenseFront, licenseBack, ocrResult, selfie, loading, success, failure }

// ─── State ───────────────────────────────────────────────────────────────────

class _KycScreenState extends State<KycScreen> with TickerProviderStateMixin {
  // Current UI step
  _KycStep _step = _KycStep.licenseFront;

  // Captured images
  File? _licenseFile;
  File? _licenseBackFile;
  File? _selfieFile;

  // OCR scan results
  String _scannedNIC = '';
  String _scannedLicense = '';
  String _scannedIssueDate = '';        // From 4a. label on front
  String _scannedExpiryDate = '';       // Latest date from Column 11 on back
  // List<String> _allColumn11Dates = []; // All Column 11 dates found on back
  final List<Map<String, String>> _extractedClasses = [];
  bool _isScanning = false;
  String _scanStatusMessage = '';       // Progress message shown during OCR
  bool _ocrMatched = false;
  bool _datesMatch = false; // true when issue date (front) & expiry date (back) match

  String _errorMsg  = '';

  // Liveness state
  bool _isLivenessActive = false;

  // Animation controller for result icon
  late AnimationController _iconAnimController;
  late Animation<double>   _iconScaleAnim;

  DocumentScanner? _documentScanner;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _documentScanner = DocumentScanner(
      options: DocumentScannerOptions(
        // `documentFormats` defaults to JPEG out of the box.
        mode: ScannerMode.filter,     // Base UI with filter controls
        pageLimit: 1,                 // Enforce 1 page per click to explicitly guide users
        isGalleryImport: true,        // Allow choosing from gallery in scanner UI
      ),
    );

    _iconAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconScaleAnim = CurvedAnimation(
      parent: _iconAnimController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _iconAnimController.dispose();
    _documentScanner?.close();
    super.dispose();
  }

  // ── Image picking & scanning helpers ───────────────────────────────────────

  /// Open the ML Kit Document Scanner with corner-detection frame overlay
  Future<void> _scanLicenseFront() async {
    try {
      final DocumentScanningResult? result = await _documentScanner?.scanDocument();

      if (result != null && result.images != null && result.images!.isNotEmpty) {
        setState(() {
          _licenseFile = File(result.images!.first);
          _step = _KycStep.licenseBack; // Move to explicitly scanning the back
        });
      }
    } catch (e) {
      if (!e.toString().contains('Canceled by user')) {
        setState(() => _errorMsg = 'Scanner Error: $e');
      }
    }
  }

  Future<void> _scanLicenseBack() async {
    try {
      final DocumentScanningResult? result = await _documentScanner?.scanDocument();

      if (result != null && result.images != null && result.images!.isNotEmpty) {
        final backImagePath = result.images!.first;

        // Guard: front image must exist before we attempt OCR
        if (_licenseFile == null) {
          setState(() {
            _errorMsg = 'Front image missing. Please restart and scan the front side again.';
            _step     = _KycStep.licenseFront;
          });
          return;
        }

        // Start scanning — stay on licenseBack step while OCR runs.
        // Both _runFrontOCR and _runBackOCR will finish, then together
        // set _step = ocrResult.
        setState(() {
          _licenseBackFile    = File(backImagePath);
          _isScanning         = true;
          // _allColumn11Dates   = [];
          _extractedClasses.clear();
          _scanStatusMessage  = 'Processing Front Side\u2026';
        });

        // Phase 1: Front OCR — NIC, License No, Issue Date (4a. label)
        await _runFrontOCR(_licenseFile!.path);

        // Phase 2: Back OCR — Column 11 expiry dates
        setState(() => _scanStatusMessage = 'Processing Back Side\u2026');
        await _runBackOCR(_licenseBackFile!.path);
      }
    } catch (e) {
      if (!e.toString().contains('Canceled by user')) {
        setState(() {
          _isScanning        = false;
          _scanStatusMessage = '';
          _errorMsg          = 'Scanner Error: $e';
          _step              = _KycStep.licenseBack;
        });
      }
    }
  }

  // ── OCR Processing ─────────────────────────────────────────────────────────

  /// Normalizes a date string to DDMMYYYY for comparison.
  /// Handles formats: dd/MM/yyyy, dd.MM.yyyy, dd-MM-yyyy, yyyy-MM-dd, yyyy/MM/dd.
  String _normalizeDateForComparison(String date) {
    final digits = date.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8) return digits;
    // If the first 4 digits form a year (>1900), it's yyyy-first format
    final first4 = int.tryParse(digits.substring(0, 4)) ?? 0;
    if (first4 > 1900) {
      // yyyy MM dd → rewrite as dd MM yyyy
      final yyyy = digits.substring(0, 4);
      final mm   = digits.substring(4, 6);
      final dd   = digits.substring(6, 8);
      return '$dd$mm$yyyy';
    }
    // Otherwise already dd MM yyyy
    return digits.substring(0, 8);
  }

  /// Parses a date string (dd.MM.yyyy or dd/MM/yyyy) into a DateTime.
  /// Returns null if parsing fails.
  DateTime? _parseDate(String d) {
    try {
      final digits = d.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length < 8) return null;
      final first4 = int.tryParse(digits.substring(0, 4)) ?? 0;
      if (first4 > 1900) {
        // yyyy MM dd
        return DateTime(
          int.parse(digits.substring(0, 4)),
          int.parse(digits.substring(4, 6)),
          int.parse(digits.substring(6, 8)),
        );
      }
      // dd MM yyyy
      return DateTime(
        int.parse(digits.substring(4, 8)),
        int.parse(digits.substring(2, 4)),
        int.parse(digits.substring(0, 2)),
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns the earliest date string from a list, by parsed DateTime value.
  String _earliestDate(List<String> dates) {
    String earliest = dates.first;
    DateTime? earliestDt = _parseDate(earliest);
    for (final d in dates.skip(1)) {
      final dt = _parseDate(d);
      if (dt != null && (earliestDt == null || dt.isBefore(earliestDt))) {
        earliest   = d;
        earliestDt = dt;
      }
    }
    return earliest;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PHASE 1 — Front Side OCR
  // Extracts: NIC (4d.), License Number (5.), Issue Date (4a. label anchor)
  // Does NOT touch expiry date — that comes from the back image.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _runFrontOCR(String imagePath) async {
    final inputImage    = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final text = recognizedText.text;

      // A. License Number Extraction (field 5 on Sri Lankan license)
      RegExp licenseNoRegExp = RegExp(r'5\.\s*([A-Z0-9\s\.\-]+)');
      RegExpMatch? licenseMatch = licenseNoRegExp.firstMatch(text);

      String rawLicense = licenseMatch?.group(1) ?? '';
      if (rawLicense.isEmpty) {
        // Fallback: prefer the [A-Z]\d{7} pattern typical of license numbers
        RegExp fallback = RegExp(r'[A-Z]\d{7}');
        rawLicense = fallback.firstMatch(text.replaceAll(RegExp(r'\s+'), ''))?.group(0) ?? '';
        
        // Only if still empty, try more generic patterns but avoid "stealing" the 12-digit NIC
        if (rawLicense.isEmpty) {
          RegExp fallback2 = RegExp(r'\b\d{8}\b'); 
          rawLicense = fallback2.firstMatch(text.replaceAll(RegExp(r'\s+'), ''))?.group(0) ?? '';
        }
      }
      String cleanLicense = rawLicense.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (cleanLicense.length > 8 && RegExp(r'^[A-Z]').hasMatch(cleanLicense)) {
        cleanLicense = cleanLicense.substring(0, 8);
      }

      // B. NIC Extraction — handles version labels 4c (new) and 4d (old)
      String scannedNIC = '';
      final sanitizedText = text.replaceAll(RegExp(r'\s+'), '');
      
      // Attempt label-anchored extraction (4c. or 4d.)
      RegExp nicLabelRegExp = RegExp(r'4[cd][.\s]*([0-9]{9}[vVxX]|[0-9]{12})');
      RegExpMatch? nicMatch = nicLabelRegExp.firstMatch(sanitizedText);
      
      if (nicMatch != null) {
        scannedNIC = nicMatch.group(1) ?? '';
      } else {
        // Fallback 1: Strong heuristic — search card for the NIC entered by the user
        final regNIC = widget.registeredNIC.toUpperCase().replaceAll(RegExp(r'\s+'), '');
        if (sanitizedText.toUpperCase().contains(regNIC)) {
          scannedNIC = widget.registeredNIC;
        } else {
          // Fallback 2: General pattern search
          RegExp nicFallback = RegExp(r'\b([0-9]{9}[vVxX]|[0-9]{12})\b');
          for (final m in nicFallback.allMatches(sanitizedText)) {
            final found = m.group(0)!;
            if (found != cleanLicense) {
              scannedNIC = found;
              break;
            }
          }
        }
      }

      // C. Issue Date Extraction — anchored to label "4a" / "4A"
      //    Deliberately does NOT capture 4b (expiry from front).
      //    Enhanced pattern handles OCR misreads (4a/4A/40/4o) and whitespace/symbols.
      String issueDate = '';
      final issueDateRegExp = RegExp(
        r'(?:4|d)[aA0oO8][^0-9]*(\d{2}[./-]\d{2}[./-]\d{4})',
        caseSensitive: false,
      );
      final issueDateMatch = issueDateRegExp.firstMatch(text.replaceAll(RegExp(r'\s+'), ''));
      if (issueDateMatch != null) {
        issueDate = issueDateMatch.group(1) ?? '';
      } else {
        // Fallback 1: use block-level bounding box — pick the date on the line
        // that matches "4a" or similar labels.
        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
            final lineText = line.text;
            if (RegExp(r'(?:4|d)[aA0oO8]', caseSensitive: false).hasMatch(lineText)) {
              final dateMatch = RegExp(r'(\d{2}[./-]\d{2}[./-]\d{4})').firstMatch(lineText);
              if (dateMatch != null) {
                issueDate = dateMatch.group(1) ?? '';
                break;
              }
            }
          }
          if (issueDate.isNotEmpty) break;
        }
      }

      // Fallback 2: Powerful heuristic — find ANY date on the front that exactly
      // matches the issue date entered by the user.
      if (issueDate.isEmpty) {
        final dateRegExp = RegExp(r'\d{2}[./-]\d{2}[./-]\d{4}');
        final allDates   = dateRegExp.allMatches(text).map((m) => m.group(0)!).toList();
        final regIssue   = _normalizeDateForComparison(widget.registeredIssueDate);
        
        for (final d in allDates) {
          if (_normalizeDateForComparison(d) == regIssue) {
            issueDate = d;
            break;
          }
        }
      }

      // D. Verify NIC and License against registration data
      final regNIC     = widget.registeredNIC.toUpperCase().replaceAll(' ', '');
      final regLicense = widget.registeredLicenseNumber.toUpperCase().replaceAll(' ', '');
      final scanNIC    = scannedNIC.toUpperCase().replaceAll(' ', '');
      final scanLicense = cleanLicense.toUpperCase().replaceAll(' ', '');

      final nicMatched     = scanNIC == regNIC;
      final licenseMatched = scanLicense == regLicense;

      // D. Verify NIC and License against registration data
      setState(() {
        _scannedNIC       = scannedNIC;
        _scannedLicense   = cleanLicense;
        _scannedIssueDate = ''; // IGNORED: Now extracted only from back side (Col. 10)
        _ocrMatched       = nicMatched && licenseMatched;
        _datesMatch       = false; // Will be determined after back OCR
      });
    } catch (e) {
      setState(() {
        _isScanning        = false;
        _scanStatusMessage = '';
        _step              = _KycStep.ocrResult;
        _errorMsg          = 'Front scan failed: $e';
      });
    } finally {
      textRecognizer.close();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PHASE 2 — Back Side OCR
  // Extracts ONLY Column 11 (Date of Expiry per category) dates.
  // Uses X-coordinate (boundingBox.left > midX) to distinguish Col 11
  // from Col 10, since OCR blocks may split dates across separate blocks.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _runBackOCR(String imagePath) async {
    final inputImage     = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final dateRegExp = RegExp(r'\d{2}[./-]\d{2}[./-]\d{4}');

      // ── Compute image width from the union of all block bounding boxes ──
      double maxRight = 0;
      for (final block in recognizedText.blocks) {
        final right = block.boundingBox.right;
        if (right > maxRight) maxRight = right;
      }

      // midX is the horizontal centre of the scanned image.
      // Column 10 (Issue) dates are in the left-centre (left < midX).
      // Column 11 (Expiry) dates are in the right half (left > midX).
      final double midX = maxRight > 0 ? maxRight / 2 : double.infinity;

      final List<String> col10Dates = []; // Issue Dates
      final List<String> col11Dates = []; // Expiry Dates

      if (midX != double.infinity) {
        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
            for (final element in line.elements) {
              final match = dateRegExp.firstMatch(element.text);
              if (match != null) {
                final dateStr = match.group(0)!;
                // Heuristic: Col 10 is on the left, Col 11 is on the right
                if (element.boundingBox.left > midX) {
                  col11Dates.add(dateStr);
                } else {
                  col10Dates.add(dateStr);
                }
              }
            }
          }
        }
      }

      // ── Fallback ─────────────────────────────────────────────────────────
      if (col11Dates.isEmpty && col10Dates.isEmpty) {
        final List<String> allDates = [];
        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
            for (final element in line.elements) {
              final match = dateRegExp.firstMatch(element.text);
              if (match != null) allDates.add(match.group(0)!);
            }
          }
        }
        // In backup, assume pairs (Col 10, Col 11)
        if (allDates.length >= 2) {
          for (int i = 0; i < allDates.length; i++) {
            if (i % 2 == 0) {
              col10Dates.add(allDates[i]);
            } else {
              col11Dates.add(allDates[i]);
            }
          }
        } else if (allDates.length == 1) {
          col11Dates.add(allDates[0]); // Default to expiry if only one found
        }
      }

      // ── Select Primary Dates ──────────────────────────────────────────────
      String earliestIssue  = col10Dates.isNotEmpty ? _earliestDate(col10Dates) : '';
      String earliestExpiry = col11Dates.isNotEmpty ? _earliestDate(col11Dates) : '';

      // ── Smart Heuristic Search ───────────────────────────────────────────
      // If the extracted dates don't match or are empty, search ALL dates on 
      // the back side for the exact dates entered by the user during signup.
      final List<String> allBackDates = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          for (final element in line.elements) {
            final match = dateRegExp.firstMatch(element.text);
            if (match != null) allBackDates.add(match.group(0)!);
          }
        }
      }

      final regIssueVal  = _normalizeDateForComparison(widget.registeredIssueDate);
      final regExpiryVal = _normalizeDateForComparison(widget.registeredExpiryDate);

      for (final foundDate in allBackDates) {
        final normFound = _normalizeDateForComparison(foundDate);
        
        // If this date matches the registered EXPIRE date, use it as earliestExpiry
        if (normFound == regExpiryVal) {
          earliestExpiry = foundDate;
        }
        // If this date matches the registered ISSUE date, use it as earliestIssue
        else if (normFound == regIssueVal) {
          earliestIssue = foundDate;
        }
      }

      // ── Re-evaluate dates match with authoritative back-side data ─────────
      final bool issueDateMatches = earliestIssue.isNotEmpty &&
          _normalizeDateForComparison(earliestIssue) == _normalizeDateForComparison(widget.registeredIssueDate);
          
      final bool expiryDateMatches = earliestExpiry.isNotEmpty &&
          _normalizeDateForComparison(earliestExpiry) == _normalizeDateForComparison(widget.registeredExpiryDate);

      setState(() {
        _scannedIssueDate  = earliestIssue;
        _scannedExpiryDate = earliestExpiry;
        // _allColumn11Dates  = col11Dates.toSet().toList();
        _datesMatch        = issueDateMatches && expiryDateMatches;
        
        if (!_datesMatch) {
          _errorMsg = 'Date Mismatch: The scan found different dates.\n'
              '• Issue Date (Col. 10): ${earliestIssue.isEmpty ? "Not Found" : earliestIssue}\n'
              '• Expiry Date (Col. 11): ${earliestExpiry.isEmpty ? "Not Found" : earliestExpiry}\n\n'
              'Please ensure you entered the Earliest Expiry date from the BACK side.';
        }

        _isScanning        = false;
        _scanStatusMessage = '';
        _step              = _KycStep.ocrResult;
      });
    } catch (e) {
      setState(() {
        _isScanning        = false;
        _scanStatusMessage = '';
        _step              = _KycStep.ocrResult;
        _errorMsg          = 'Back scan failed: $e';
      });
    } finally {
      textRecognizer.close();
    }
  }



  // ── Submission (face verification removed — liveness is sufficient) ──────────

  // ── Reset for retry ─────────────────────────────────────────────────────────

  void _retry() {
    setState(() {
      _licenseFile       = null;
      _licenseBackFile   = null;
      _selfieFile        = null;
      _scannedNIC        = '';
      _scannedLicense    = '';
      _scannedIssueDate  = '';
      _scannedExpiryDate = '';
      // _allColumn11Dates  = [];
      _scanStatusMessage = '';
      _ocrMatched        = false;
      _datesMatch        = false;
      _errorMsg          = '';
      _step              = _KycStep.licenseFront;
    });
    _iconAnimController.reset();
  }

  void _retrySelfie() {
    setState(() {
      _selfieFile = null;
      _errorMsg   = '';
      _step       = _KycStep.selfie;
    });
    _iconAnimController.reset();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Identity Verification'),
        backgroundColor: AppColors.primaryGreenDark,
        foregroundColor: Colors.white,
        elevation: 0,
        // Hide back arrow during loading / final result
        automaticallyImplyLeading:
            _step != _KycStep.loading && _step != _KycStep.success,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _KycStep.licenseFront:
        return _buildLicenseFrontStep();
      case _KycStep.licenseBack:
        return _buildLicenseBackStep();
      case _KycStep.ocrResult:
        return _buildOcrResultStep();
      case _KycStep.selfie:
        return _buildSelfieStep();
      case _KycStep.loading:
        return _buildLoadingStep();
      case _KycStep.success:
        return _buildSuccessStep();
      case _KycStep.failure:
        return _buildFailureStep();
    }
  }

  // ── Step 1: License Photo ───────────────────────────────────────────────────

  Widget _buildLicenseFrontStep() {
    return SingleChildScrollView(
      key: const ValueKey('licenseFront'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepIndicator(currentStep: 1, totalSteps: 5),
          const SizedBox(height: 28),

          // Illustration area
          _illustrationCard(
            icon:  Icons.credit_card,
            color: AppColors.primaryGreen,
            title: 'Driving License Photo',
            subtitle:
                'Upload a clear, well-lit photo of your driving license (front side). '
                'Make sure your face, NIC number, and license number are visible.',
          ),

          const SizedBox(height: 32),

          // Preview if already selected
          if (_licenseFile != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              child: Image.file(_licenseFile!, height: 180, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
          ],

          // Scanning indicator
          if (_isScanning) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
            const SizedBox(height: 8),
            const Text(
              'Scanning license details…',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            // Action buttons
            _primaryButton(
              label:   'Scan Front Side',
              icon:    Icons.document_scanner,
              onTap:   _scanLicenseFront,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  // ── Step 2: License Back Photo ─────────────────────────────────────────────

  Widget _buildLicenseBackStep() {
    return SingleChildScrollView(
      key: const ValueKey('licenseBack'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepIndicator(currentStep: 2, totalSteps: 5),
          const SizedBox(height: 28),

          // Illustration area
          _illustrationCard(
            icon:  Icons.flip,
            color: AppColors.primaryGreen,
            title: 'Scan Back Side',
            subtitle:
                'Now tap to scan the back side of your driving license. '
                'This helps us read your allowed vehicle categories.',
          ),

          const SizedBox(height: 32),

          if (_isScanning) ...[
            const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
            const SizedBox(height: 8),
            Text(
              _scanStatusMessage.isNotEmpty
                  ? _scanStatusMessage
                  : 'Analyzing license data…',
              style: const TextStyle(
                color:      AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Please wait, this may take a few seconds.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            _primaryButton(
              label:   'Scan Back Side',
              icon:    Icons.flip,
              onTap:   _scanLicenseBack,
            ),
          ],
        ],
      ),
    );
  }

  // ── Step 3: OCR Result ──────────────────────────────────────────────────────

  Widget _buildOcrResultStep() {
    return SingleChildScrollView(
      key: const ValueKey('ocrResult'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepIndicator(currentStep: 3, totalSteps: 5),
          const SizedBox(height: 28),

          const Text(
            'Scanned License Details',
            style: TextStyle(
              fontSize: AppTextSize.heading2,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _ocrMatched && _datesMatch
                ? 'All license details match your registration. Proceed to selfie.'
                : 'Some details do not match. Please retake the photo or check your registration.',
            style: TextStyle(
              fontSize: AppTextSize.bodyMedium,
              color: _ocrMatched && _datesMatch ? AppColors.successGreen : AppColors.errorRed,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Scanned data card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.large),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _ocrRow(
                  label:    'NIC Number',
                  scanned:  _scannedNIC.isEmpty ? 'Not detected' : _scannedNIC,
                  expected: widget.registeredNIC,
                  matches:  _scannedNIC.toUpperCase().replaceAll(' ', '') ==
                            widget.registeredNIC.toUpperCase().replaceAll(' ', ''),
                ),
                const Divider(),
                _ocrRow(
                  label:    'License Number',
                  scanned:  _scannedLicense.isEmpty ? 'Not detected' : _scannedLicense,
                  expected: widget.registeredLicenseNumber,
                  matches:  _scannedLicense.toUpperCase().replaceAll(' ', '') ==
                            widget.registeredLicenseNumber.toUpperCase().replaceAll(' ', ''),
                ),
                const Divider(),
                _ocrRow(
                  label:    'Issue Date',
                  scanned:  _scannedIssueDate.isEmpty ? 'Not detected' : _scannedIssueDate,
                  expected: widget.registeredIssueDate,
                  matches:  _scannedIssueDate.isNotEmpty &&
                            _normalizeDateForComparison(_scannedIssueDate) ==
                            _normalizeDateForComparison(widget.registeredIssueDate),
                ),
                const Divider(),
                _ocrRow(
                  label:    'Expiry Date (from back — Col 11)',
                  scanned:  _scannedExpiryDate.isEmpty ? 'Not detected' : _scannedExpiryDate,
                  expected: widget.registeredExpiryDate,
                  matches:  _scannedExpiryDate.isNotEmpty &&
                            _normalizeDateForComparison(_scannedExpiryDate) ==
                            _normalizeDateForComparison(widget.registeredExpiryDate),
                ),
                // if (_allColumn11Dates.isNotEmpty) ...[
                //   const Divider(),
                //   const Padding(
                //     padding: EdgeInsets.symmetric(vertical: 4),
                //     child: Text(
                //       'All Column 11 Expiry Dates (Back)',
                //       style: TextStyle(
                //         fontSize: AppTextSize.bodySmall,
                //         color: AppColors.textSecondary,
                //         fontWeight: FontWeight.w600,
                //       ),
                //     ),
                //   ),
                //   Wrap(
                //     spacing: 8,
                //     runSpacing: 4,
                //     children: _allColumn11Dates.map((d) => Chip(
                //       label: Text(
                //         d,
                //         style: TextStyle(
                //           fontSize: 11,
                //           fontWeight: FontWeight.bold,
                //           color: d == _scannedExpiryDate
                //               ? AppColors.successGreen
                //               : AppColors.textPrimary,
                //         ),
                //       ),
                //       backgroundColor: d == _scannedExpiryDate
                //           ? AppColors.successBg
                //           : Colors.grey.shade100,
                //       side: BorderSide(
                //         color: d == _scannedExpiryDate
                //             ? AppColors.successGreen
                //             : Colors.grey.shade300,
                //       ),
                //       padding: const EdgeInsets.symmetric(horizontal: 4),
                //     )).toList(),
                //   ),
                // ],
                if (_extractedClasses.isNotEmpty) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Allowed Vehicle Classes',
                      style: TextStyle(
                        fontSize: AppTextSize.bodySmall,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8.0, 
                    runSpacing: 8.0,
                    children: _extractedClasses.map((c) => Chip(
                      label: Text("${c['category']}\nIss: ${c['issueDate']}\nExp: ${c['expiryDate']}"), 
                      backgroundColor: Colors.green[50],
                      side: const BorderSide(color: AppColors.successGreen),
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // \u2500\u2500 Dates not detected warning \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
          if (_scannedIssueDate.isEmpty || _scannedExpiryDate.isEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: AppColors.errorRed),
              ),
              child: const Row(
                children: [
                  Icon(Icons.camera_enhance, color: AppColors.errorRed, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Could not read one or more dates from the license. '
                      'Retake with better lighting and ensure all dates are clearly visible.',
                      style: TextStyle(color: AppColors.errorRed, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          // \u2500\u2500 Dates detected but do not match \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
          ] else if (!_datesMatch) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color:        AppColors.errorBg,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border:       Border.all(color: AppColors.errorRed),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.errorRed, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The dates on your license do not match what you entered. '
                      'Please retake the license photo or go back and correct the dates.',
                      style: TextStyle(color: AppColors.errorRed, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // \u2500\u2500 Proceed button (only when all 4 checks pass) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
          if (_ocrMatched && _datesMatch) ...[
            _primaryButton(
              label: 'Proceed to Selfie',
              icon:  Icons.camera_front,
              onTap: () => setState(() => _step = _KycStep.selfie),
            ),
          ],
          const SizedBox(height: 12),
          _secondaryButton(
            label: 'Retake License Photo',
            icon:  Icons.refresh,
            onTap: () {
              setState(() {
                _licenseFile       = null;
                _licenseBackFile   = null;
                _scannedNIC        = '';
                _scannedLicense    = '';
                _scannedIssueDate  = '';
                _scannedExpiryDate = '';
                // _allColumn11Dates  = [];
                _scanStatusMessage = '';
                _ocrMatched        = false;
                _datesMatch        = false;
                _extractedClasses.clear();
                _step              = _KycStep.licenseFront;
              });
            },
          ),
        ],
      ),
    );
  }

  // ── OCR Row Helpers ─────────────────────────────────────────────────────────

  Widget _ocrRow({
    required String label,
    required String scanned,
    required String expected,
    required bool matches,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTextSize.bodySmall,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scanned: $scanned',
                      style: TextStyle(
                        fontSize: AppTextSize.bodyMedium,
                        color: matches ? AppColors.textPrimary : AppColors.errorRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Expected: $expected',
                      style: const TextStyle(
                        fontSize: AppTextSize.bodySmall,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                matches ? Icons.check_circle : Icons.cancel,
                color: matches ? AppColors.successGreen : AppColors.errorRed,
                size: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }



  // ── Step 3: Selfie ──────────────────────────────────────────────────────────

  Widget _buildSelfieStep() {
    if (_isLivenessActive) {
      return Container(
        key: const ValueKey('liveness_camera'),
        color: Colors.black,
        child: Stack(
          children: [
            LivenessCameraView(
              onCompleted: (File capturedFile) async {
                setState(() {
                  _selfieFile = capturedFile;
                  _isLivenessActive = false;
                  _step = _KycStep.loading;
                });

                try {
                  // Convert captured selfie to base64
                  final bytes = await _selfieFile!.readAsBytes();
                  final profileImageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';

                  // Convert license images to base64
                  final licenseFrontBytes = await _licenseFile!.readAsBytes();
                  final licenseFrontBase64 = 'data:image/jpeg;base64,${base64Encode(licenseFrontBytes)}';

                  final licenseBackBytes = await _licenseBackFile!.readAsBytes();
                  final licenseBackBase64 = 'data:image/jpeg;base64,${base64Encode(licenseBackBytes)}';

                  // Mark as success and show success animation
                  setState(() {
                    _step = _KycStep.success;
                  });

                  _iconAnimController.forward(from: 0);

                  // Wait 2 seconds to show success animation
                  await Future.delayed(const Duration(seconds: 2));

                  // Switch to saving/loading state while DB write completes
                  if (!mounted) return;
                  setState(() => _step = _KycStep.loading);

                  // Await the onVerified callback — it writes to the DB and
                  // navigates to LoginScreen. The KYC screen stays frozen here
                  // until that completes (or throws).
                  await widget.onVerified(
                    _scannedIssueDate,
                    _scannedExpiryDate,
                    _extractedClasses,
                    profileImageBase64,
                    licenseFrontBase64,
                    licenseBackBase64,
                  );
                } catch (e) {
                  debugPrint('[KYC] Error processing images: $e');
                  setState(() {
                    _step = _KycStep.failure;
                    _errorMsg = 'Failed to process images. Please try again.';
                  });
                  _iconAnimController.forward(from: 0);
                }
              },
              onError: (error) {
                setState(() {
                  _isLivenessActive = false;
                  _errorMsg = error;
                  _step = _KycStep.failure;
                });
                _iconAnimController.forward(from: 0);
              },
            ),
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => setState(() => _isLivenessActive = false),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      key: const ValueKey('selfie'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepIndicator(currentStep: 3, totalSteps: 4),
          const SizedBox(height: 28),

          _illustrationCard(
            icon:  Icons.face,
            color: AppColors.primaryBlue,
            title: 'Liveness Verification',
            subtitle:
                'To verify you are a live human, we need to perform a quick test. '
                'You will be asked to Blink, Smile, and then return to a Neutral expression.',
          ),

          const SizedBox(height: 32),

          if (_selfieFile != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              child: Image.file(_selfieFile!, height: 220, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
          ],

          _primaryButton(
            label:   'Start Liveness Test',
            icon:    Icons.camera_front,
            onTap:   () => setState(() => _isLivenessActive = true),
          ),
          const SizedBox(height: 12),
          _secondaryButton(
            label: 'Back',
            icon:  Icons.arrow_back,
            onTap: () => setState(() => _step = _KycStep.ocrResult),
          ),
        ],
      ),
    );
  }

  // ── Step 4: Preview removed — verification completes automatically after liveness ──

  // ── Loading ─────────────────────────────────────────────────────────────────

  Widget _buildLoadingStep() {
    return Center(
      key: const ValueKey('loading'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.primaryGreen,
            strokeWidth: 3.5,
          ),
          const SizedBox(height: 28),
          Text(
            'Saving your data…',
            style: TextStyle(
              fontSize: AppTextSize.bodyLarge,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we create your account.',
            style: TextStyle(
              fontSize: AppTextSize.bodySmall,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  // ── Success ─────────────────────────────────────────────────────────────────

  Widget _buildSuccessStep() {
    return Center(
      key: const ValueKey('success'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _iconScaleAnim,
              child: Container(
                width:  120,
                height: 120,
                decoration: BoxDecoration(
                  color:  AppColors.successBg,
                  shape:  BoxShape.circle,
                  border: Border.all(color: AppColors.successGreen, width: 3),
                ),
                child: const Icon(
                  Icons.verified_user,
                  size:  60,
                  color: AppColors.successGreen,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Identity Verified!',
              style: TextStyle(
                fontSize:   AppTextSize.heading1,
                fontWeight: FontWeight.bold,
                color:      AppColors.successGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Liveness verification completed successfully.\nYour registration is being processed.',
              style: const TextStyle(
                fontSize: AppTextSize.bodyMedium,
                color:    AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon:    const Icon(Icons.arrow_forward),
                label:   const Text('Continue Registration'),
                style:   ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreenDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                ),
                // Button intentionally hidden — onVerified() is called automatically
                // after liveness completes (2-second delay for success animation).
                onPressed: null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Failure ─────────────────────────────────────────────────────────────────

  Widget _buildFailureStep() {
    return Center(
      key: const ValueKey('failure'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _iconScaleAnim,
              child: Container(
                width:  120,
                height: 120,
                decoration: BoxDecoration(
                  color:  AppColors.errorBg,
                  shape:  BoxShape.circle,
                  border: Border.all(color: AppColors.errorRed, width: 3),
                ),
                child: const Icon(
                  Icons.cancel,
                  size:  60,
                  color: AppColors.errorRed,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Verification Failed',
              style: TextStyle(
                fontSize:   AppTextSize.heading1,
                fontWeight: FontWeight.bold,
                color:      AppColors.errorRed,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMsg.isNotEmpty ? _errorMsg : 'Please try again with clearer photos.',
              style: const TextStyle(
                fontSize: AppTextSize.bodyMedium,
                color:    AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // ── Retry Logic ───────────────────────────────────────────
            if (_licenseFile != null && _licenseBackFile != null) ...[
              // Most likely a face-match failure or submit error after successful scan
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon:    const Icon(Icons.face),
                  label:   const Text('Retake Selfie & Try Again'),
                  style:   ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreenDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                  ),
                  onPressed: _retrySelfie,
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                icon:    const Icon(Icons.refresh, size: 18),
                label:   const Text('Restart Full Verification'),
                style:   TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                onPressed: _retry,
              ),
            ] else ...[
              // Failure happened before/during license scan
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon:    const Icon(Icons.refresh),
                  label:   const Text('Try Again'),
                  style:   ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreenDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                  ),
                  onPressed: _retry,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Reusable sub-widgets ────────────────────────────────────────────────────

  Widget _stepIndicator({required int currentStep, required int totalSteps}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (i) {
        final isActive = i + 1 == currentStep;
        final isDone   = i + 1 < currentStep;
        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width:  isActive ? 32 : 24,
              height: isActive ? 32 : 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? AppColors.successGreen
                    : isActive
                        ? AppColors.primaryGreen
                        : Colors.grey.shade300,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          color:      isActive ? Colors.white : Colors.grey.shade600,
                          fontSize:   12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            if (i < totalSteps - 1)
              Container(
                width:  28,
                height: 2,
                color:  isDone ? AppColors.successGreen : Colors.grey.shade300,
              ),
          ],
        );
      }),
    );
  }

  Widget _illustrationCard({
    required IconData icon,
    required Color    color,
    required String   title,
    required String   subtitle,
  }) {
    return Container(
      padding:      const EdgeInsets.all(20),
      decoration:   BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color:  Colors.grey.withValues(alpha: 0.1),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize:   AppTextSize.heading3,
              fontWeight: FontWeight.bold,
              color:      AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: AppTextSize.bodyMedium,
              color:    AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String   label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        icon:  Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: AppTextSize.bodyLarge)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreenDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
        ),
        onPressed: onTap,
      ),
    );
  }

  Widget _secondaryButton({
    required String   label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        icon:  Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: AppTextSize.bodyMedium)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreenDark,
          side:            const BorderSide(color: AppColors.primaryGreenDark),
          shape:           RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
        ),
        onPressed: onTap,
      ),
    );
  }
}
