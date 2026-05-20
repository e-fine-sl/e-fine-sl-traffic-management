import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/accident_service.dart';
import '../../config/app_constants.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? _selectedAccidentType;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;
  int _officersNotified = 0;
  String _resolvedProvince = '';
  String _resolvedDistrict = '';
  String _resolvedDivision = '';
  String? _errorMessage;
  final AccidentService _accidentService = AccidentService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];

  final List<Map<String, String>> _accidentTypes = [
    { 
      'emoji': '🚗', 
      'label': 'Vehicle Collision', 
      'desc': 'Crash between cars, bikes, or trucks' 
    },
    { 
      'emoji': '🚶', 
      'label': 'Pedestrian Accident', 
      'desc': 'Accident involving a person walking' 
    },
    { 
      'emoji': '🏃', 
      'label': 'Hit & Run', 
      'desc': 'Vehicle hit someone and drove away' 
    },
    { 
      'emoji': '⚠️', 
      'label': 'Road Hazard', 
      'desc': 'Blocked road, fallen tree, or potholes' 
    },
    { 
      'emoji': '📋', 
      'label': 'Other', 
      'desc': 'Any other emergency not listed' 
    },
  ];

  String _getLocalizedTypeLabel(String label) {
    switch (label) {
      case 'Vehicle Collision': return 'report_screen.type_vehicle_collision'.tr();
      case 'Pedestrian Accident': return 'report_screen.type_pedestrian_accident'.tr();
      case 'Hit & Run': return 'report_screen.type_hit_run'.tr();
      case 'Road Hazard': return 'report_screen.type_road_hazard'.tr();
      case 'Other': return 'report_screen.type_other'.tr();
      default: return label;
    }
  }

  String _getLocalizedTypeDesc(String label) {
    switch (label) {
      case 'Vehicle Collision': return 'report_screen.desc_vehicle_collision'.tr();
      case 'Pedestrian Accident': return 'report_screen.desc_pedestrian_accident'.tr();
      case 'Hit & Run': return 'report_screen.desc_hit_run'.tr();
      case 'Road Hazard': return 'report_screen.desc_road_hazard'.tr();
      case 'Other': return 'report_screen.desc_other'.tr();
      default: return '';
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('report_screen.max_images_error'.tr()))
      );
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Compress for faster upload
    );

    if (image != null) {
      setState(() {
        _selectedImages.add(File(image.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitReport() async {
    if (_selectedAccidentType == null) {
      setState(() => _errorMessage = 'report_screen.select_type_error'.tr());
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('report_screen.confirm_title'.tr()),
          content: Text('report_screen.confirm_content'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('report_screen.cancel'.tr()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('report_screen.send_alert'.tr(), style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final position = await _accidentService.getCurrentLocation();
      
      final licenseNumber = await _storage.read(key: 'licenseNumber');
      if (licenseNumber == null || licenseNumber.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'report_screen.license_not_found'.tr();
        });
        return;
      }

      final String desc = _descriptionController.text.trim();
      final result = await _accidentService.reportAccident(
        licenseNumber: licenseNumber,
        lat: position.latitude,
        lng: position.longitude,
        accidentType: _selectedAccidentType!,
        description: desc.isEmpty ? null : desc,
        images: _selectedImages.isNotEmpty ? _selectedImages : null,
      );

      if (result['success'] == true) {
        setState(() {
          _isLoading = false;
          _isSuccess = true;
          _officersNotified = result['officersNotified'] as int? ?? 0;
          _resolvedProvince = result['province'] as String? ?? '';
          _resolvedDistrict = result['district'] as String? ?? '';
          _resolvedDivision = result['policeDivision'] as String? ?? '';
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result['message'] as String? ?? 'report_screen.failed_alert'.tr();
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Widget _buildSuccessView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 96, color: Colors.green),
          const SizedBox(height: 24),
          Text(
            'report_screen.success_title'.tr(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 12),
          Text(
            'report_screen.success_officers'.tr(args: [_officersNotified.toString()]),
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'report_screen.success_email'.tr(),
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (_resolvedProvince.isNotEmpty) ...[
            Text(
              'report_screen.province_district'.tr(args: [_resolvedProvince, _resolvedDistrict]),
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            Text(
              'report_screen.police_division'.tr(args: [_resolvedDivision]),
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('report_screen.done'.tr(), style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SECTION 1 — Header Banner
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.red, Colors.orange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_police, size: 48, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('report_screen.banner_title'.tr(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('report_screen.banner_subtitle'.tr(), style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // SECTION 2 — Accident Type Selector
        Text('report_screen.select_type_label'.tr(), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _accidentTypes.map((option) {
            final isSelected = _selectedAccidentType == option['label'];
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedAccidentType = isSelected ? null : option['label'];
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.red.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.red.shade300 : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(option['emoji']!, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getLocalizedTypeLabel(option['label']!),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.red.shade800 : Colors.black87,
                            ),
                          ),
                          Text(
                            _getLocalizedTypeDesc(option['label']!),
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.red.shade600 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: Colors.red.shade600, size: 20),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // SECTION 3 — Description TextFormField
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          maxLength: 200,
          decoration: InputDecoration(
            labelText: 'report_screen.details_label'.tr(),
            hintText: 'report_screen.details_hint'.tr(),
            helperText: 'report_screen.details_helper'.tr(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 24),

        // SECTION 3.5 — Image Picker
        Text('report_screen.photos_label'.tr(), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        const SizedBox(height: 12),
        if (_selectedImages.isNotEmpty)
          Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(_selectedImages[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_a_photo),
            label: Text(_selectedImages.isEmpty ? 'report_screen.add_photos'.tr() : 'report_screen.add_more_photos'.tr()),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // SECTION 4 — Location Info Card
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(child: Text('report_screen.gps_notice'.tr(), style: const TextStyle(color: Colors.blue, fontSize: 13))),
            ],
          ),
        ),

        // SECTION 5 — Warning Note
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'report_screen.warning_notice'.tr(),
                  style: const TextStyle(color: Colors.orange, fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        // SECTION 6 — Error message
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ),

        // SECTION 7 — Submit Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _submitReport,
            child: _isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Text('report_screen.sending_alert'.tr(), style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send, color: Colors.white),
                      const SizedBox(width: 8),
                      Text('report_screen.send_accident_alert'.tr(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('report_screen.appbar_title'.tr(), style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.errorRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isSuccess ? _buildSuccessView() : _buildReportForm(),
          ),
        ),
      ),
    );
  }
}
