import 'package:flutter/material.dart';
import '../../config/app_constants.dart';
import '../../services/police_dashboard_service.dart';
import 'police_text.dart';

class SosFab extends StatefulWidget {
  final String location;
  final String officerName;

  const SosFab({
    super.key,
    required this.location,
    required this.officerName,
  });

  @override
  State<SosFab> createState() => _SosFabState();
}

class _SosFabState extends State<SosFab> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final PoliceDashboardService _service = PoliceDashboardService();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleSos() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: PoliceText('police.dashboard_sos_title', style: const TextStyle(color: AppColors.errorRed)),
        content: PoliceText('police.dashboard_sos_confirm'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: PoliceText('police.home_close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: PoliceText('police.dashboard_sos_send'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSending = true);
    final success = await _service.registerSosAlert(widget.location, widget.officerName);
    
    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS Backup Requested! HQ Notified.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send SOS request.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.errorRed.withValues(alpha: 0.5 * _pulseController.value),
                spreadRadius: 8 * _pulseController.value,
                blurRadius: 10,
              ),
            ],
          ),
          child: FloatingActionButton(
            backgroundColor: AppColors.errorRed,
            onPressed: _isSending ? null : _handleSos,
            child: _isSending 
              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              : const Icon(Icons.sos, color: Colors.white, size: 28),
          ),
        );
      },
    );
  }
}
