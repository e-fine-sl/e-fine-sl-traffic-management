// lib/screens/police/driver_record_screen.dart
//
// Shown after an officer scans a driver's QR code: scanned identity,
// demerit score and full fine history, with a button to issue a new fine.

import 'package:flutter/material.dart';
import '../../config/app_constants.dart';
import '../../services/police_locale_service.dart';
import '../../widgets/police/driver_record_card.dart';
import 'new_fine.dart';

class DriverRecordScreen extends StatefulWidget {
  /// Decoded QR payload (type: driver_identity).
  final Map<String, dynamic> scannedData;

  const DriverRecordScreen({super.key, required this.scannedData});

  @override
  State<DriverRecordScreen> createState() => _DriverRecordScreenState();
}

class _DriverRecordScreenState extends State<DriverRecordScreen> {
  // Bumped after a fine is issued so the record reloads
  int _reloadKey = 0;

  String _t(String key) => PoliceLocaleService.instance.translate(key);

  @override
  Widget build(BuildContext context) {
    final data = widget.scannedData;
    final license = (data['license'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('police.record_screen_title')),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle(Icons.verified_user, _t('police.record_scanned_identity')),
          Card(
            elevation: 0,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey[100],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _detailRow(Icons.person, _t('police.record_name'), data['name'] ?? 'N/A'),
                  const Divider(),
                  _detailRow(Icons.badge, _t('police.record_nic'), data['nic'] ?? 'N/A'),
                  const Divider(),
                  _detailRow(Icons.card_membership, _t('police.record_license'), license.isEmpty ? 'N/A' : license),
                  const Divider(),
                  _detailRow(Icons.directions_car, _t('police.record_vehicle'), data['vehicleNumber'] ?? 'N/A'),
                  const Divider(),
                  _detailRow(Icons.phone, _t('police.record_contact'),
                      data['phone'] ?? data['contactNumber'] ?? 'N/A'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t('police.home_verify_hint'),
            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _sectionTitle(Icons.history, _t('police.record_title')),
          if (license.isNotEmpty)
            DriverRecordCard(
              key: ValueKey('$license-$_reloadKey'),
              licenseNumber: license,
              maxInlineFines: 5,
            ),
          const SizedBox(height: 90),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NewFineScreen(
                      scannedLicenseNumber: data['license'],
                      scannedVehicleNumber: data['vehicleNumber'],
                    ),
                  ),
                );
                if (mounted) setState(() => _reloadKey++);
              },
              icon: const Icon(Icons.edit_note, color: Colors.white),
              label: Text(
                _t('police.home_issue_fine'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 20),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 17, color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 11)),
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
