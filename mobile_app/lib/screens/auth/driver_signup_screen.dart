import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import '../../config/app_constants.dart';
import '../kyc_screen.dart'; // KYC face verification

class DriverSignupScreen extends StatefulWidget {
  const DriverSignupScreen({super.key});

  @override
  State<DriverSignupScreen> createState() => _DriverSignupScreenState();
}

class _DriverSignupScreenState extends State<DriverSignupScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading    = false;
  bool _kycVerified  = false; // Set to true after KYC passes
  List<Map<String, String>> _vehicleClasses = [];
  String? _profileImageBase64;
  String? _licenseFrontBase64;
  String? _licenseBackBase64;

  final _nameController = TextEditingController();
  final _nicController = TextEditingController();
  final _licenseController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  // Password Visibility
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Real-time Validation State
  Timer? _debounce;
  
  bool _isCheckingNic = false;
  String? _nicErrorText;
  bool _isNicUnique = false;

  bool _isCheckingLicense = false;
  String? _licenseErrorText;
  bool _isLicenseUnique = false;

  bool _isCheckingEmail = false;
  String? _emailErrorText;
  bool _isEmailUnique = false;

  bool _isCheckingPhone = false;
  String? _phoneErrorText;
  bool _isPhoneUnique = false;

  // DMT verification state
  bool _isDmtChecking = false;
  bool _isDmtVerified = false;
  String? _dmtErrorText;

  @override
  void initState() {
    super.initState();
    _nicController.addListener(() => _onFieldChanged('nic', _nicController.text));
    _licenseController.addListener(() => _onFieldChanged('licenseNumber', _licenseController.text));
    _emailController.addListener(() => _onFieldChanged('email', _emailController.text));
    _phoneController.addListener(() => _onFieldChanged('phone', _phoneController.text));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _nicController.dispose();
    _licenseController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  // --- REAL-TIME VALIDATION LOGIC 

  void _onFieldChanged(String field, String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    // Immediately clear "unique" status if user types something new
    // We will wait until debounce to re-check
    setState(() {
      switch (field) {
        case 'nic':
          _isNicUnique = false;
          _nicErrorText = null;
          if (value.isNotEmpty) {
            _isCheckingNic = true;
          } else {
            _isCheckingNic = false; // Empty field means not checking
          }
          break;
        case 'licenseNumber':
          _isLicenseUnique = false;
          _licenseErrorText = null;
          if (value.isNotEmpty) {
            _isCheckingLicense = true;
          } else {
            _isCheckingLicense = false;
          }
          break;
        case 'email':
          _isEmailUnique = false;
          _emailErrorText = null;
          if (value.isNotEmpty) {
            _isCheckingEmail = true;
          } else {
            _isCheckingEmail = false;
          }
          break;
        case 'phone':
          _isPhoneUnique = false;
          _phoneErrorText = null;
          if (value.isNotEmpty) {
            _isCheckingPhone = true;
          } else {
            _isCheckingPhone = false;
          }
          break;
      }
    });

    if (value.trim().isEmpty) return;

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      // First do local regex checks if applicable
      if (field == 'email' && !_isValidEmail(value)) {
        setState(() {
          _isCheckingEmail = false;
          _emailErrorText = "Invalid email format";
        });
        return;
      }
      if (field == 'nic' && !_isValidNIC(value)) {
        setState(() {
          _isCheckingNic = false;
          _nicErrorText = "Invalid NIC format";
        });
        return;
      }
      if (field == 'phone' && !_isValidPhone(value)) {
        setState(() {
          _isCheckingPhone = false;
          _phoneErrorText = "Invalid phone format";
        });
        return;
      }

      // Reset DMT state whenever NIC changes
      // (forces re-verification with new NIC value)
      if (field == 'nic') {
        setState(() {
          _isDmtVerified = false;
          _dmtErrorText  = null;
        });
      }

      // Check DB
      final isTaken = await _authService.checkFieldExists(field, value.trim(), role: 'driver');
      
      if (!mounted) return;

      if (field == 'licenseNumber') {
        if (isTaken) {
          setState(() {
            _isCheckingLicense = false;
            _isLicenseUnique   = false;
            _isDmtVerified     = false;
            _dmtErrorText      = null;
            _licenseErrorText  = "License Number is already registered in e-Fine SL";
          });
          return; // Stop — do not call DMT
        }

        // ── Step 2: DMT verification (NEW) ────────────────────────────
        setState(() {
          _isCheckingLicense = false;
          _isLicenseUnique   = false;
          _isDmtChecking     = true;
          _dmtErrorText      = null;
        });

        final dmtResult = await _authService.verifyLicenseWithDMT(
          licenseNumber: value.trim(),
          nic:           _nicController.text.trim(),
        );

        if (!mounted) return;

        if (dmtResult['success'] == true) {
          setState(() {
            _isDmtChecking  = false;
            _isDmtVerified  = true;
            _isLicenseUnique = true;
            _licenseErrorText = null;
            _dmtErrorText     = null;
          });
        } else if (dmtResult['dmtUnreachable'] == true) {
          setState(() {
            _isDmtChecking  = false;
            _isDmtVerified  = false;
            _isLicenseUnique = false;
            _dmtErrorText   = "⚠️ DMT verification service is unavailable. "
                              "Registration is blocked. Please try again later.";
          });
        } else if (dmtResult['found'] == false) {
          setState(() {
            _isDmtChecking  = false;
            _isDmtVerified  = false;
            _isLicenseUnique = false;
            _dmtErrorText   = "License Number not found in DMT records. "
                              "Please check your driving license.";
          });
        } else if (dmtResult['nicMatch'] == false) {
          setState(() {
            _isDmtChecking  = false;
            _isDmtVerified  = false;
            _isLicenseUnique = false;
            _dmtErrorText   = "NIC Number does not match this License Number "
                              "in the DMT records. Please check both values.";
          });
        } else {
          setState(() {
            _isDmtChecking  = false;
            _isDmtVerified  = false;
            _isLicenseUnique = false;
            _dmtErrorText   = dmtResult['message'] ?? "DMT verification failed.";
          });
        }
        return;
      }

      setState(() {
        switch (field) {
          case 'nic':
            _isCheckingNic = false;
            if (isTaken) {
              _nicErrorText = "NIC is already registered";
            } else {
              _isNicUnique = true;
            }
            break;
          case 'email':
            _isCheckingEmail = false;
            if (isTaken) {
              _emailErrorText = "Email is already registered";
            } else {
              _isEmailUnique = true;
            }
            break;
          case 'phone':
            _isCheckingPhone = false;
            if (isTaken) {
              _phoneErrorText = "Phone is already registered";
            } else {
              _isPhoneUnique = true;
            }
            break;
        }
      });
    });
  }


  // --- VALIDATION FUNCTIONS

  // 1. Email Validation
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // 2. NIC Validation (Sri Lanka: 9 digits+V/X or 12 digits)
  bool _isValidNIC(String nic) {
    return RegExp(r'^([0-9]{9}[vVxX]|[0-9]{12})$').hasMatch(nic);
  }

  // 3. Phone Validation (Sri Lanka: 10 digits starting with 0)
  bool _isValidPhone(String phone) {
    return RegExp(r'^0[0-9]{9}$').hasMatch(phone);
  }

  // 4. Strong Password Validation
  // (Min 8 chars, Letters, Numbers, Special Character)
  bool _isPasswordStrong(String password) {
    if (password.length < 8) return false; 
    if (!password.contains(RegExp(r'[A-Za-z]'))) return false; 
    if (!password.contains(RegExp(r'[0-9]'))) return false; 
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false; 
    return true;
  }

 
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.errorRed),
    );
  }

  // ── Field validation (shared between KYC gate and final submit) ────────────
  bool _validateFields() {
    if (_nameController.text.isEmpty ||
        _nicController.text.isEmpty ||
        _licenseController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _addressLine1Controller.text.isEmpty ||
        _cityController.text.isEmpty ||
        _postalCodeController.text.isEmpty) {
      _showError("Please fill all fields.");
      return false;
    }

    // DMT verification must pass before KYC
    if (!_isDmtVerified) {
      _showError(
        'Your License Number must be verified against the DMT database '
        'before you can proceed with registration.'
      );
      return false;
    }

    if (!_isValidNIC(_nicController.text)) {
      _showError("Invalid NIC Number (Format: 123456789V or 199012345678)");
      return false;
    }
    if (!_isValidEmail(_emailController.text)) {
      _showError("Please enter a valid Email Address.");
      return false;
    }
    if (!_isValidPhone(_phoneController.text)) {
      _showError("Invalid Phone Number (Must be 10 digits, e.g., 0712345678)");
      return false;
    }
    if (!_isPasswordStrong(_passwordController.text)) {
      _showError("Password must include 8+ chars, numbers, letters & symbols (@#\$).");
      return false;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError("Passwords do not match!");
      return false;
    }
    return true;
  }

  bool _isAllUniqueFieldsValid() {
    return _isNicUnique &&
           _isLicenseUnique &&
           _isEmailUnique &&
           _isPhoneUnique;
  }

  Widget? _buildSuffixIcon(bool isChecking, bool isUnique) {
    if (isChecking) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (isUnique) {
      return const Icon(Icons.check_circle, color: AppColors.successGreen);
    }
    return null;
  }

  Widget? _buildLicenseSuffixIcon() {
    if (_isCheckingLicense || _isDmtChecking) {
      return const SizedBox(
        width: 20, height: 20,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_isDmtVerified && _isLicenseUnique) {
      return const Icon(Icons.verified, color: AppColors.successGreen);
    }
    if (_dmtErrorText != null || _licenseErrorText != null) {
      return const Icon(Icons.gpp_bad, color: AppColors.errorRed);
    }
    return null;
  }

  // ── Phase 1: open KYC screen (called when KYC not yet done) ─────────────────
  void _openKyc() {
    if (!_validateFields()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KycScreen(
          registeredNIC: _nicController.text,
          registeredLicenseNumber: _licenseController.text,
          onVerified: (classes, profileImageBase64, frontBase64, backBase64) async {
            // Called when KYC liveness succeeds.
            // This runs WHILE the KYC screen shows a loading overlay; navigation to
            // LoginScreen happens at the end of _registerDriver(), not here.
            setState(() {
              _kycVerified        = true;
              _vehicleClasses     = classes;
              _profileImageBase64 = profileImageBase64;
              _licenseFrontBase64 = frontBase64;
              _licenseBackBase64  = backBase64;
            });
            await _registerDriver();
          },
        ),
      ),
    );
  }

  // ── Phase 2: final registration submit (called after KYC passes) ─────────────
  Future<void> _registerDriver() async {
    if (!_validateFields()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.registerDriver({
        'name':          _nameController.text,
        'nic':           _nicController.text,
        'licenseNumber': _licenseController.text,
        'email':         _emailController.text,
        'phone':         _phoneController.text,
        'password':      _passwordController.text,
        'kycVerified':   _kycVerified,   // ← KYC flag saved to DB
        'isVerified':    _kycVerified,   // ← Mark as fully verified
        'vehicleClasses':    _vehicleClasses,
        'profileImage':      _profileImageBase64,
        'licenseFrontImage': _licenseFrontBase64,
        'licenseBackImage':  _licenseBackBase64,
        'addressLine1':      _addressLine1Controller.text.trim(),
        'addressLine2':      _addressLine2Controller.text.trim(),
        'city':              _cityController.text.trim(),
        'postalCode':        _postalCodeController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:         Text("Registration Successful! Please Login."),
            backgroundColor: AppColors.successGreen,
          ),
        );
        // Navigate to LoginScreen, clearing the entire navigation stack.
        // This is called from the KYC screen's loading overlay — the user
        // never sees the registration form again.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Registration"),
        backgroundColor: AppColors.primaryGreenDark, 
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.directions_car, size: 60, color: AppColors.primaryGreen),
            const SizedBox(height: 10),
            const Text(
              "Create Driver Account",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 25),

            // Full Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),

            // NIC
            TextField(
              controller: _nicController,
              decoration: InputDecoration(
                labelText: "NIC Number", 
                prefixIcon: const Icon(Icons.credit_card), 
                border: const OutlineInputBorder(), 
                helperText: "Ex: 901234567V or 199012345678",
                errorText: _nicErrorText,
                suffixIcon: _buildSuffixIcon(_isCheckingNic, _isNicUnique),
              ),
            ),
            const SizedBox(height: 15),

            // License Number
            TextField(
              controller: _licenseController,
              decoration: InputDecoration(
                labelText: "Driving License Number", 
                prefixIcon: const Icon(Icons.card_membership), 
                border: const OutlineInputBorder(),
                errorText: _licenseErrorText,
                suffixIcon: _buildLicenseSuffixIcon(),
              ),
            ),
            
            // DMT Verification Error Message (shown below the field)
            Visibility(
              visible: _dmtErrorText != null,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 12.0, right: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.errorRed, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _dmtErrorText ?? "",
                        style: const TextStyle(color: AppColors.errorRed, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Email
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Email Address", 
                prefixIcon: const Icon(Icons.email), 
                border: const OutlineInputBorder(),
                errorText: _emailErrorText,
                suffixIcon: _buildSuffixIcon(_isCheckingEmail, _isEmailUnique),
              ),
            ),
            const SizedBox(height: 15),

            // Phone
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Mobile Number",
                prefixIcon: const Icon(Icons.phone),
                border: const OutlineInputBorder(),
                helperText: "Ex: 0771234567",
                errorText: _phoneErrorText,
                suffixIcon: _buildSuffixIcon(_isCheckingPhone, _isPhoneUnique),
              ),
            ),
            const SizedBox(height: 20),

            // Password
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: "Password",
                prefixIcon: const Icon(Icons.lock),
                border: const OutlineInputBorder(),
                helperText: "8+ chars, numbers, symbols (@#\$)",
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              decoration: InputDecoration(
                labelText: "Confirm Password",
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Residential Address Section
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Residential Address", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressLine1Controller,
              decoration: const InputDecoration(labelText: "Address Line 1", prefixIcon: Icon(Icons.home), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressLine2Controller,
              decoration: const InputDecoration(labelText: "Address Line 2 (Optional)", prefixIcon: Icon(Icons.home_outlined), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: "City", prefixIcon: Icon(Icons.location_city), border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _postalCodeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Postal Code", border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── KYC verified chip (shown after KYC passes) ────────────────
            if (_kycVerified)
              Container(
                margin:  const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color:        AppColors.successBg,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border:       Border.all(color: AppColors.successGreen),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user, color: AppColors.successGreen, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Identity Verified ✔',
                      style: TextStyle(
                        color:      AppColors.successGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Register / Verify & Register button ───────────────────────
            SizedBox(
              width:  double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                // If not yet KYC-verified → open KYC screen first
                // If already verified    → re-submit (edge case safety)
                onPressed: (_isLoading || !_isAllUniqueFieldsValid())
                    ? null
                    : (_kycVerified ? _registerDriver : _openKyc),
                icon:  const Icon(Icons.verified_user),
                label: _isLoading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        _kycVerified ? 'Complete Registration' : 'Verify Identity & Register',
                        style: const TextStyle(fontSize: 16),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreenDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}