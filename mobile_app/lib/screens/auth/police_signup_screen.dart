import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import '../../config/app_constants.dart';

class PoliceSignupScreen extends StatefulWidget {
  const PoliceSignupScreen({super.key});

  @override
  State<PoliceSignupScreen> createState() => _PoliceSignupScreenState();
}

class _PoliceSignupScreenState extends State<PoliceSignupScreen> {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isStationsLoading = true;

  // Controllers
  final _nameController = TextEditingController();
  final _badgeController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _nicController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Toggles
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Data Lists
  List<Map<String, dynamic>> stationList = [];
  String? selectedStationCode;
  
  // --- 1. MISSING VARIABLES FIXED ---
  String? _selectedRank;
  File? _imageFile;
  String? _base64Image;

  final List<String> _policeRanks = [
    'Constable',
    'Sergeant',
    'Sub-Inspector (SI)',
    'Inspector (IP)',
    'Chief Inspector (CI)',
    'OIC',
    'ASP'
  ];

  @override
  void initState() {
    super.initState();
    _fetchStations();
  }

  Future<void> _fetchStations() async {
    try {
      final stations = await _authService.getStations();
      setState(() {
        stationList = stations;
        _isStationsLoading = false;
      });
    } catch (e) {
      _showError("Failed to load stations: ${e.toString()}");
      setState(() => _isStationsLoading = false);
    }
  }

  // --- 2. IMAGE CAPTURE FUNCTION ---
  Future<void> _captureImage() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera, 
        imageQuality: 50, 
        preferredCameraDevice: CameraDevice.front
      );

      if (photo != null) {
        List<int> imageBytes = await File(photo.path).readAsBytes();
        String base64String = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';

        setState(() {
          _imageFile = File(photo.path);
          _base64Image = base64String;
        });
      }
    } catch (e) {
      _showError("Camera Error: $e");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shows a prominent blocking Dialog for HQ-level security denial messages.
  /// Use this for badge validation errors — they should not be easily missed.
  void _showSecurityDenialDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('UNDERSTOOD', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- VALIDATIONS ---
  bool _isPasswordStrong(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false; 
    return true;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidNIC(String nic) {
    return RegExp(r'^([0-9]{9}[vVxX]|[0-9]{12})$').hasMatch(nic);
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^0[0-9]{9}$').hasMatch(phone);
  }

  // --- API CALLS ---

  Future<void> _requestOTP() async {
    if (_badgeController.text.isEmpty || selectedStationCode == null) {
      _showError("Please fill Badge ID and select Station");
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.requestVerification(
        _badgeController.text.trim(),
        selectedStationCode!,
      );
      setState(() => _currentStep = 1);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      // Show prominent dialog for HQ-level badge rejections
      if (msg.contains('not recognized by Headquarters') ||
          msg.contains('Registration Denied')) {
        _showSecurityDenialDialog('Access Denied by HQ', msg);
      } else {
        _showError(msg);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.length < 6) {
      _showError("Please enter valid 6-digit OTP");
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.verifyOTP(
        _badgeController.text,
        _otpController.text,
      );
      setState(() => _currentStep = 2);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeRegistration() async {
    // Basic Empty Checks
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _nicController.text.isEmpty || 
        _phoneController.text.isEmpty) {
      _showError("Please fill all details.");
      return;
    }

    // Rank Check
    if (_selectedRank == null) {
      _showError("Please select your Rank / Position.");
      return;
    }

    // Image Check
    if (_base64Image == null) {
      _showError("Profile Picture is mandatory! Please tap the camera icon.");
      return;
    }

    // Validations
    if (!_isValidEmail(_emailController.text)) {
      _showError("Please enter a valid Email Address.");
      return;
    }
    if (!_isValidNIC(_nicController.text)) {
      _showError("Invalid NIC Number");
      return;
    }
    if (!_isValidPhone(_phoneController.text)) {
      _showError("Invalid Phone Number");
      return;
    }
    if (!_isPasswordStrong(_passwordController.text)) {
      _showError("Password too weak.");
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError("Passwords do not match!");
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // Sending All Data
      await _authService.registerPolice({
        'name': _nameController.text.trim(),
        'badgeNumber': _badgeController.text.trim(),
        'email': _emailController.text.trim(),
        'nic': _nicController.text.trim(),
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text,
        'station': selectedStationCode, 
        'otp': _otpController.text.trim(),
        'position': _selectedRank,
        'profileImage': _base64Image,
      });
      
      if (mounted) {
        _showSuccess("Registration Successful! Please Login.");
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');

      // Badge pre-approval denial (401) 
      if (msg.contains('not recognized by Headquarters') ||
          msg.contains('Registration Denied')) {
        _showSecurityDenialDialog('Access Denied by HQ', msg);
      }
      // Badge already used (400) 
      else if (msg.contains('already exists') &&
               msg.toLowerCase().contains('badge')) {
        _showSecurityDenialDialog('Badge Already Registered', msg);
      }
     
      else {
        _showError(msg);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Police Registration"),
        backgroundColor: AppColors.primaryBlue, 
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            
            // STEP 1: Request OTP
            if (_currentStep == 0) ...[
              const Text("Step 1: Verification Request", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const SizedBox(height: 25),
              TextField(
                controller: _badgeController,
                decoration: const InputDecoration(labelText: "Badge Number / Service ID", prefixIcon: Icon(Icons.badge), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              if (_isStationsLoading)
                const Center(child: CircularProgressIndicator()) 
              else 
                DropdownSearch<Map<String, dynamic>>(
                  compareFn: (item1, item2) => item1['code'] == item2['code'],
                  items: (filter, loadProps) => stationList,
                  itemAsString: (item) => item['name'],
                  onChanged: (val) => setState(() => selectedStationCode = val?['code']),
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(decoration: InputDecoration(hintText: "Search...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder())),
                  ),
                  decoratorProps: const DropDownDecoratorProps(decoration: InputDecoration(labelText: "Select Police Station", prefixIcon: Icon(Icons.local_police), border: OutlineInputBorder())),
                  filterFn: (item, filter) => item['name'].toLowerCase().contains(filter.toLowerCase()),
                ),
              const SizedBox(height: 30),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _isLoading ? null : _requestOTP, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Request Verification Code"))),
            ],

            // STEP 2: Verify OTP
            if (_currentStep == 1) ...[
              const Text("Step 2: Enter Verification Code", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(controller: _otpController, keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 6, decoration: const InputDecoration(labelText: "6-Digit OTP", border: OutlineInputBorder())),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _isLoading ? null : _verifyOTP, style: ElevatedButton.styleFrom(backgroundColor: AppColors.successGreen, foregroundColor: Colors.white), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Verify Code"))),
            ],

            // STEP 3: Complete Profile
            if (_currentStep == 2) ...[
              const Text("Step 3: Officer Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
              const SizedBox(height: 20),
              
              // Camera Capture
              Center(
                child: GestureDetector(
                  onTap: _captureImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                        child: _imageFile == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                                  Text("Tap to Photo", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                          child: const Icon(Icons.add_a_photo, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text("* Photo is Mandatory", style: TextStyle(color: AppColors.errorRed, fontSize: 12)),
              const SizedBox(height: 20),

              TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
              const SizedBox(height: 15),

              // Rank Dropdown (Fixed: using initialValue)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Select Rank / Position",
                  prefixIcon: Icon(Icons.security),
                  border: OutlineInputBorder(),
                ),
                initialValue: _selectedRank,
                items: _policeRanks.map((String rank) {
                  return DropdownMenuItem<String>(
                    value: rank,
                    child: Text(rank),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedRank = newValue;
                  });
                },
              ),
              const SizedBox(height: 15),

              TextField(controller: _nicController, decoration: const InputDecoration(labelText: "NIC Number", prefixIcon: Icon(Icons.credit_card), border: OutlineInputBorder())),
              const SizedBox(height: 15),

              TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Mobile Number", prefixIcon: Icon(Icons.phone), border: OutlineInputBorder())),
              const SizedBox(height: 15),
              
              TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Email Address", prefixIcon: Icon(Icons.email), border: OutlineInputBorder())),
              const SizedBox(height: 15),
              
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: "Create Password", prefixIcon: const Icon(Icons.lock), border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)),
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                decoration: InputDecoration(
                  labelText: "Confirm Password", prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible)),
                ),
              ),
              const SizedBox(height: 30),
              
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _isLoading ? null : _completeRegistration, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("COMPLETE REGISTRATION"))),
            ],
          ],
        ),
      ),
    );
  }
}