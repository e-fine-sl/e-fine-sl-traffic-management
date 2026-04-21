import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/police_locale_service.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../../config/app_constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _storage = const FlutterSecureStorage();
  final ImagePicker _picker = ImagePicker();
  final AuthService _authService = AuthService();

  String _userId = "";
  String _officerName = "";
  String _badgeNumber = "";
  String _email = "";
  String _station = "";
  String _position = "";

  String? _profileImageBase64;
  bool _isUploading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _fetchLatestUserData();
  }

  Future<void> _fetchLatestUserData() async {
    try {
      String? savedId = await _storage.read(key: PrefKeys.userId);
      String? savedName = await _storage.read(key: PrefKeys.userName);

      if (mounted) {
        setState(() {
          if (savedId != null) _userId = savedId;
          if (savedName != null) _officerName = savedName;
        });
      }

      final userData = await _authService.getUserProfile();

      if (mounted) {
        setState(() {
          _userId = userData['_id'] ?? _userId;
          _officerName = userData['name'] ?? "Unknown";
          _badgeNumber = userData['badgeNumber'] ?? "Not Assigned";
          _email = userData['email'] ?? "No Email";
          _position = userData['position'] ?? "Officer";

          if (userData['policeStation'] is Map) {
            _station =
                userData['policeStation']['name'] ?? "Unknown Station";
          } else {
            _station = userData['policeStation'] ?? "Unknown Station";
          }

          _profileImageBase64 = userData['profileImage'];
          _isLoadingData = false;
        });

        await _storage.write(key: PrefKeys.userName, value: _officerName);
        await _storage.write(key: 'badgeNumber', value: _badgeNumber);
        await _storage.write(key: 'position', value: _position);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedFile != null) {
      setState(() => _isUploading = true);

      try {
        List<int> imageBytes = await File(pickedFile.path).readAsBytes();
        String base64String =
            'data:image/jpeg;base64,${base64Encode(imageBytes)}';

        await _authService.updateProfileImage(_userId, base64String);

        if (mounted) {
          setState(() {
            _profileImageBase64 = base64String;
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(PoliceLocaleService.instance.translate('police.profile_photo_updated')),
                backgroundColor: AppColors.successGreen),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(PoliceLocaleService.instance.translate('police.profile_photo_failed')),
                backgroundColor: AppColors.errorRed),
          );
        }
      }
    }
  }

  ImageProvider _getProfileImage() {
    if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty) {
      if (_profileImageBase64!.startsWith('data:image')) {
        try {
          final base64Data = _profileImageBase64!.split(',').last;
          return MemoryImage(base64Decode(base64Data));
        } catch (e) {
          return const NetworkImage(
              'https://cdn-icons-png.flaticon.com/512/206/206853.png');
        }
      } else {
        return NetworkImage(_profileImageBase64!);
      }
    }
    return const NetworkImage(
        'https://cdn-icons-png.flaticon.com/512/206/206853.png');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(PoliceLocaleService.instance.translate('police.profile_appbar_title'),
            style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primaryBlue, width: 3),
                          ),
                          child: CircleAvatar(
                            radius: 70,
                            backgroundColor: Colors.white,
                            child: _isUploading
                                ? const CircularProgressIndicator()
                                : CircleAvatar(
                                    radius: 70,
                                    backgroundColor: Colors.transparent,
                                    backgroundImage: _getProfileImage(),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap:
                                _isUploading ? null : _pickAndUploadImage,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      blurRadius: 5, color: Colors.black26)
                                ],
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),
                  Text(_officerName,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue)),
                  Text(_position.toUpperCase(),
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600)),

                  const SizedBox(height: 30),

                  _buildInfoCard(
                      Icons.badge,
                      PoliceLocaleService.instance.translate('police.profile_badge'),
                      _badgeNumber),
                  const SizedBox(height: 15),
                  _buildInfoCard(
                      Icons.local_police,
                      PoliceLocaleService.instance.translate('police.profile_station'),
                      _station),
                  const SizedBox(height: 15),
                  _buildInfoCard(
                      Icons.email,
                      PoliceLocaleService.instance.translate('police.profile_email'),
                      _email),

                  const SizedBox(height: 40),

                  // LOGOUT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _storage.deleteAll();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (context) => const LoginScreen()),
                            (Route<dynamic> route) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: Text(PoliceLocaleService.instance.translate('police.profile_logout'),
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.errorRed,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3))
          ]),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.primaryBlue)),
          const SizedBox(width: 20),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 5),
                Text(value,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                    overflow: TextOverflow.ellipsis)
              ])),
        ],
      ),
    );
  }
}
