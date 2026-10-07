import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:mobile_app/config/app_constants.dart';
import '../../services/accident_service.dart';
import '../../widgets/driver/accident_type_card.dart';
import '../../widgets/driver/photo_attachment_zone.dart';
import '../../widgets/driver/info_banner.dart';

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

  // ── Accident type definitions using Material Icons ──
  final List<Map<String, dynamic>> _accidentTypes = [
    {
      'icon': Icons.directions_car_rounded,
      'label': 'Vehicle Collision',
      'desc': 'Two or more vehicles crashed — cars, bikes, tuktuk, or trucks',
    },
    {
      'icon': Icons.directions_walk_rounded,
      'label': 'Pedestrian Accident',
      'desc': 'A person walking or crossing the road was hit by a vehicle',
    },
    {
      'icon': Icons.directions_run_rounded,
      'label': 'Hit & Run',
      'desc': 'A vehicle caused damage or injury and left the scene',
    },
    {
      'icon': Icons.report_problem_rounded,
      'label': 'Road Hazard',
      'desc': 'Fallen tree, damaged road, flood, or any road blockage',
    },
    {
      'icon': Icons.description_rounded,
      'label': 'Other',
      'desc': 'Any other road emergency not listed above',
    },
  ];

  // ── Localization helpers (unchanged logic) ──
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
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFC62828), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'report_screen.confirm_title'.tr(),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: Text(
            'report_screen.confirm_content'.tr(),
            style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF475569)),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'report_screen.cancel'.tr(),
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('report_screen.send_alert'.tr()),
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

  // ═══════════════════════════════════════════════════════
  // SUCCESS VIEW
  // ═══════════════════════════════════════════════════════
  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success icon with soft green background
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 48,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'report_screen.success_title'.tr(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'report_screen.success_officers'.tr(args: [_officersNotified.toString()]),
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'report_screen.success_email'.tr(),
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (_resolvedProvince.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _detailRow(Icons.location_on_outlined, 'Province', '$_resolvedProvince, $_resolvedDistrict'),
                    const SizedBox(height: 8),
                    _detailRow(Icons.local_police_outlined, 'Division', _resolvedDivision),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(  
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  'report_screen.done'.tr(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // REPORT FORM
  // ═══════════════════════════════════════════════════════
  Widget _buildReportForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Header ──
        Text(
          'report_screen.banner_title'.tr(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'report_screen.banner_subtitle'.tr(),
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 24),

        // ── Accident Type Selection ──
        Text(
          'report_screen.select_type_label'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Color(0xFF475569),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        ..._accidentTypes.map((option) {
          final bool isSelected = _selectedAccidentType == option['label'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AccidentTypeCard(
              icon: option['icon'] as IconData,
              label: _getLocalizedTypeLabel(option['label'] as String),
              description: _getLocalizedTypeDesc(option['label'] as String),
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  _selectedAccidentType = isSelected ? null : option['label'] as String;
                });
              },
            ),
          );
        }),
        const SizedBox(height: 24),

        // ── Description Field ──
        Text(
          'report_screen.details_label'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Color(0xFF475569),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          maxLength: 200,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'report_screen.details_hint'.tr(),
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            helperText: 'report_screen.details_helper'.tr(),
            helperStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFC62828), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Photo Attachment ──
        Text(
          'report_screen.photos_label'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Color(0xFF475569),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        PhotoAttachmentZone(
          images: _selectedImages,
          maxImages: 3,
          onAddPhoto: _pickImage,
          onRemovePhoto: _removeImage,
        ),
        const SizedBox(height: 24),

        // ── Info Banners ──
        InfoBanner(
          icon: Icons.my_location_rounded,
          text: 'report_screen.gps_notice'.tr(),
          variant: InfoBannerVariant.info,
        ),
        const SizedBox(height: 10),
        InfoBanner(
          icon: Icons.info_outline_rounded,
          text: 'report_screen.warning_notice'.tr(),
          variant: InfoBannerVariant.warning,
        ),
        const SizedBox(height: 20),

        // ── Error Message ──
        if (_errorMessage != null) ...[
          InfoBanner(
            icon: Icons.error_outline_rounded,
            text: _errorMessage!,
            variant: InfoBannerVariant.error,
          ),
          const SizedBox(height: 16),
        ],

        // ── Submit Button ──
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: _isLoading ? null : _submitReport,
            child: _isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'report_screen.sending_alert'.tr(),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.emergency_share_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'report_screen.send_accident_alert'.tr(),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // SCAFFOLD
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'report_screen.appbar_title'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFFC62828),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: _isSuccess ? _buildSuccessView() : _buildReportForm(),
          ),
        ),
      ),
    );
  }
}
