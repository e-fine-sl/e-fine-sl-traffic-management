// lib/widgets/police/driver_record_card.dart
//
// Officer view of a driver's record: profile, demerit score (out of 24),
// summary of past fines and the fine history list.
// Used on the QR scan result screen and on the New Fine screen.

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/app_constants.dart';
import '../../services/fine_service.dart';
import '../../services/police_locale_service.dart';

String _t(String key) => PoliceLocaleService.instance.translate(key);

/// Colors / labels for demerit weights (2 = minor ... 8 = critical).
class DemeritStyle {
  static Color colorFor(num points) {
    if (points >= 8) return AppColors.errorRed;
    if (points >= 6) return Colors.deepOrange;
    if (points >= 4) return AppColors.warningOrange;
    return Colors.blueGrey;
  }

  static String severityKey(num points) {
    if (points >= 8) return 'police.severity_critical';
    if (points >= 6) return 'police.severity_serious';
    if (points >= 4) return 'police.severity_moderate';
    return 'police.severity_minor';
  }

  /// Color for the driver's remaining score (e.g. 15 / 24).
  static Color scoreColor(num points, num max) {
    if (points <= 0) return AppColors.dangerRed;
    final ratio = max == 0 ? 0 : points / max;
    if (ratio >= 0.8) return AppColors.goodStanding;
    if (ratio >= 0.4) return AppColors.warningLevel;
    return AppColors.dangerLevel;
  }
}

/// Small colored "-6 pts" chip.
class DemeritChip extends StatelessWidget {
  final num points;
  const DemeritChip({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final color = DemeritStyle.colorFor(points);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        "-$points ${_t('police.points_short')}",
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}

class DriverRecordCard extends StatefulWidget {
  final String licenseNumber;

  /// How many fines to list inline; the rest open in a bottom sheet.
  final int maxInlineFines;

  /// Called once the record is loaded (used by New Fine to preview the score after the fine).
  final ValueChanged<Map<String, dynamic>>? onLoaded;

  const DriverRecordCard({
    super.key,
    required this.licenseNumber,
    this.maxInlineFines = 3,
    this.onLoaded,
  });

  @override
  State<DriverRecordCard> createState() => _DriverRecordCardState();
}

class _DriverRecordCardState extends State<DriverRecordCard> {
  Map<String, dynamic>? _record;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final record = await FineService().getDriverRecord(widget.licenseNumber);
      if (!mounted) return;
      setState(() {
        _record = record;
        _loading = false;
      });
      widget.onLoaded?.call(record);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll("Exception:", "").trim();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.errorRed),
          const SizedBox(height: 6),
          Text(_t('police.record_failed'), style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: Text(_t('police.record_retry')),
          ),
        ],
      );
    }

    final record = _record!;
    final driver = record['driver'] as Map<String, dynamic>?;
    final summary = Map<String, dynamic>.from(record['summary'] ?? {});
    final fines = List<Map<String, dynamic>>.from(record['fines'] ?? []);
    final maxPoints = (record['maxPoints'] ?? 24) as num;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (driver != null) ...[
          _buildDriverHeader(context, driver),
          const SizedBox(height: 12),
          if (driver['licenseStatus'] == 'SUSPENDED') ...[
            _buildBanner(Icons.block, _t('police.record_suspended_warning'), AppColors.errorRed),
            const SizedBox(height: 12),
          ],
          _buildScore(context, driver, maxPoints),
        ] else
          _buildBanner(Icons.person_off_outlined, _t('police.record_not_registered'), AppColors.warningOrange),
        const SizedBox(height: 12),
        _buildSummary(context, summary),
        const SizedBox(height: 12),
        Text(
          _t('police.record_recent'),
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
        ),
        const SizedBox(height: 6),
        if (fines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.verified, color: AppColors.successGreen, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(_t('police.record_no_fines'))),
              ],
            ),
          )
        else ...[
          ...fines.take(widget.maxInlineFines).map((f) => FineHistoryTile(fine: f)),
          if (fines.length > widget.maxInlineFines)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showAllFines(context, fines),
                icon: const Icon(Icons.list_alt),
                label: Text("${_t('police.record_view_all')} (${fines.length})"),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildDriverHeader(BuildContext context, Map<String, dynamic> driver) {
    final suspended = driver['licenseStatus'] == 'SUSPENDED';
    final statusColor = suspended ? AppColors.suspendedRed : AppColors.activeGreen;

    ImageProvider? avatar;
    final img = driver['profileImage'] as String?;
    if (img != null && img.isNotEmpty) {
      try {
        avatar = MemoryImage(base64Decode(img.split(',').last));
      } catch (_) {}
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
          backgroundImage: avatar,
          child: avatar == null ? const Icon(Icons.person, color: AppColors.primaryBlue) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (driver['name'] ?? 'N/A').toString().trim(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                driver['licenseNumber'] ?? '',
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            suspended ? _t('police.record_license_suspended') : _t('police.record_license_active'),
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildScore(BuildContext context, Map<String, dynamic> driver, num maxPoints) {
    final points = (driver['demeritPoints'] ?? maxPoints) as num;
    final rating = driver['ratingScore'] ?? 0;
    final level = (driver['demeritLevel'] ?? '').toString().toLowerCase();
    final color = DemeritStyle.scoreColor(points, maxPoints);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(_t('police.record_score'), style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              "$points / $maxPoints ${_t('police.points_short')}",
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: maxPoints == 0 ? 0 : (points / maxPoints).clamp(0, 1).toDouble(),
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 16),
            const SizedBox(width: 4),
            Text("$rating / 5.0", style: const TextStyle(fontSize: 12)),
            const Spacer(),
            if (level.isNotEmpty)
              Text(
                PoliceLocaleService.instance.translate('demerit_$level'),
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context, Map<String, dynamic> summary) {
    final unpaidCount = summary['unpaidCount'] ?? 0;
    return Row(
      children: [
        _summaryTile(context, _t('police.record_total_fines'), "${summary['totalFines'] ?? 0}", AppColors.primaryBlue),
        _summaryTile(
          context,
          _t('police.record_unpaid'),
          "$unpaidCount\nRs. ${summary['unpaidAmount'] ?? 0}",
          unpaidCount > 0 ? AppColors.errorRed : AppColors.successGreen,
        ),
        _summaryTile(context, _t('police.record_points_lost'), "${summary['totalDemeritDeducted'] ?? 0}", Colors.deepOrange),
      ],
    );
  }

  Widget _summaryTile(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  void _showAllFines(BuildContext context, List<Map<String, dynamic>> fines) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                "${_t('police.record_title')} (${fines.length})",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: fines.length,
                itemBuilder: (_, i) => FineHistoryTile(fine: fines[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One past fine in the driver's history.
class FineHistoryTile extends StatelessWidget {
  final Map<String, dynamic> fine;
  const FineHistoryTile({super.key, required this.fine});

  @override
  Widget build(BuildContext context) {
    final paid = (fine['status'] ?? '').toString().toUpperCase() == 'PAID';
    final statusColor = paid ? AppColors.successGreen : AppColors.warningOrange;
    final date = DateTime.tryParse(fine['date'] ?? '')?.toLocal();
    final dateText = date == null
        ? ''
        : "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final points = (fine['demeritPoints'] ?? 0) as num;
    final code = fine['offenseCode'];
    final section = fine['sectionOfAct'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  fine['offenseName'] ?? 'N/A',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text("Rs. ${fine['amount'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              dateText,
              if (code != null) code,
              if (section != null) "${_t('police.section_short')} $section",
              fine['vehicleNumber'],
            ].where((e) => e != null && e.toString().isNotEmpty).join(" • "),
            style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
          ),
          if ((fine['place'] ?? '').toString().isNotEmpty)
            Text(
              fine['place'],
              style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  paid ? _t('police.record_status_paid') : _t('police.record_status_unpaid'),
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              if (points > 0) DemeritChip(points: points),
            ],
          ),
        ],
      ),
    );
  }
}
