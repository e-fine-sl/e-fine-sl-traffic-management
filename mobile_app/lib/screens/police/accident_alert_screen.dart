import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_constants.dart';

class AccidentAlertScreen extends StatefulWidget {
  final String accidentType;
  final String driverName;
  final String licenseNumber;
  final String driverPhone;
  final String description;
  final double lat;
  final double lng;
  final String province;
  final String district;
  final String policeDivision;
  final String reportedAt;
  final String reportId;

  const AccidentAlertScreen({
    super.key,
    required this.accidentType,
    required this.driverName,
    required this.licenseNumber,
    required this.driverPhone,
    required this.description,
    required this.lat,
    required this.lng,
    required this.province,
    required this.district,
    required this.policeDivision,
    required this.reportedAt,
    required this.reportId,
  });

  @override
  State<AccidentAlertScreen> createState() => _AccidentAlertScreenState();
}

class _AccidentAlertScreenState extends State<AccidentAlertScreen> {
  bool _isOpening = false;

  String _getTypeIcon(String type) {
    switch (type) {
      case 'Vehicle Collision':
        return '';
      case 'Pedestrian Accident':
        return '';
      case 'Hit & Run':
        return '';
      case 'Road Hazard / Obstruction':
        return '';
      default:
        return '';
    }
  }

  Future<void> _openInMaps() async {
    setState(() => _isOpening = true);
    final url = Uri.parse('https://maps.google.com/?q=${widget.lat},${widget.lng}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Google Maps')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening maps: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[50],
      appBar: AppBar(
        title: const Text('Accident Alert', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        leading: const BackButton(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ALERT BANNER
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red[900]!, Colors.red[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ACCIDENT REPORTED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                widget.accidentType,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Reported: ${widget.reportedAt}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // CARD A - Accident Details
              _buildInfoCard(
                title: 'Incident Details',
                icon: Icons.info_outline,
                iconColor: Colors.red,
                children: [
                  _buildDetailRow('Type', '${_getTypeIcon(widget.accidentType)} ${widget.accidentType}'),
                  _buildDetailRow('Location', '${widget.policeDivision}, ${widget.district}'),
                  _buildDetailRow('Province', widget.province),
                ],
              ),

              // CARD B - Driver Information
              _buildInfoCard(
                title: 'Reporting Driver',
                icon: Icons.person,
                iconColor: Colors.blue,
                children: [
                  _buildDetailRow('Name', widget.driverName),
                  _buildDetailRow('License', widget.licenseNumber),
                  _buildDetailRow(
                    'Phone',
                    widget.driverPhone.isEmpty ? 'Not provided' : widget.driverPhone,
                    trailing: widget.driverPhone.isNotEmpty
                        ? InkWell(
                            onTap: () => launchUrl(Uri.parse('tel:${widget.driverPhone}')),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone, color: Colors.green, size: 16),
                                SizedBox(width: 4),
                                Text('Call', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        : null,
                  ),
                ],
              ),

              // CARD C - Description
              if (widget.description.isNotEmpty)
                _buildInfoCard(
                  title: 'Description',
                  icon: Icons.description,
                  iconColor: Colors.orange,
                  children: [
                    Text(
                      widget.description,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
              
              const SizedBox(height: 24),

              // ACTION BUTTONS
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isOpening ? null : _openInMaps,
                  icon: const Icon(Icons.map, color: Colors.white),
                  label: Text(
                    _isOpening ? 'Opening Maps...' : 'Track Location on Google Maps',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Acknowledged — Close Alert'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red[700]!),
                    foregroundColor: Colors.red[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
