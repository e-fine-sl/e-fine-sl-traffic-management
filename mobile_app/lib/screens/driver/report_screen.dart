import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only add up to 3 images'))
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
      setState(() => _errorMessage = 'Please select an accident type');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🚨 Send Accident Alert?'),
          content: const Text(
            'This will immediately notify nearby police officers and the '
            'police station about the accident at your current location.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Send Alert', style: TextStyle(color: Colors.white)),
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
          _errorMessage = 'License number not found. Please log in again.';
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
          _errorMessage = result['message'] as String? ?? 'Failed to send alert';
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
          const Text(
            'Alert Sent Successfully!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 12),
          Text(
            '$_officersNotified officer(s) have been notified near your location',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'The nearest police station has also been alerted via email',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (_resolvedProvince.isNotEmpty) ...[
            Text(
              'Province: $_resolvedProvince | District: $_resolvedDistrict',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            Text(
              'Police Division: $_resolvedDivision',
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
              child: const Text('Done', style: TextStyle(color: Colors.white)),
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
          child: const Row(
            children: [
              Icon(Icons.local_police, size: 48, color: Colors.white),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Report an Accident', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Alert nearby officers and the police station instantly', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // SECTION 2 — Accident Type Selector
        const Text('Select Accident Type *', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
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
                            option['label']!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.red.shade800 : Colors.black87,
                            ),
                          ),
                          Text(
                            option['desc']!,
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
            labelText: 'Additional Details (Optional)',
            hintText: 'Use English or Sinhala (ඉංග්‍රීසි හෝ සිංහල)',
            helperText: 'You can describe in English or Sinhala language.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 24),

        // SECTION 3.5 — Image Picker
        const Text('Attach Photos (Optional - Max 3)', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
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
            label: Text(_selectedImages.isEmpty ? 'Add Photos' : 'Add More Photos'),
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
          child: const Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(child: Text('Your current GPS location will be automatically captured.', style: TextStyle(color: Colors.blue, fontSize: 13))),
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
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This alert will immediately notify all police officers within 5 km and the nearest police station. Only use for genuine road accidents.',
                  style: TextStyle(color: Colors.orange, fontSize: 13),
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
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Sending Alert...', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Send Accident Alert', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
        title: const Text('Report Accident', style: TextStyle(color: Colors.white)),
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
