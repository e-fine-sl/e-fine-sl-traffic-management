import 'package:flutter/material.dart';
import '../../models/police_dashboard_model.dart';
import '../../config/app_constants.dart';

class HQAlertsWidget extends StatelessWidget {
  final List<HqAlertModel> alerts;

  const HQAlertsWidget({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.grey, size: 30),
            SizedBox(width: 15),
            Text(
              "No active HQ alerts",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      );
    }

    // Just show the top active alert for simplicity
    final alert = alerts.first;

    Color bannerColor;
    switch (alert.severity.toLowerCase()) {
      case 'critical':
        bannerColor = AppColors.errorRed;
        break;
      case 'high':
        bannerColor = AppColors.warningOrange;
        break;
      default:
        bannerColor = AppColors.primaryBlue;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  alert.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
