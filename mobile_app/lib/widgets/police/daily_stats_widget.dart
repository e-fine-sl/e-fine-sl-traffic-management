import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/app_constants.dart';
import 'police_text.dart';

class DailyStatsWidget extends StatelessWidget {
  final int dailyFinesCount;
  final double dailyTotalAmount;
  final bool isLoading;

  const DailyStatsWidget({
    super.key,
    required this.dailyFinesCount,
    required this.dailyTotalAmount,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Row(
        children: [
          Expanded(child: _buildShimmerCard()),
          const SizedBox(width: 15),
          Expanded(child: _buildShimmerCard()),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            titleKey: 'police.dashboard_fines_today',
            value: dailyFinesCount.toString(),
            icon: Icons.receipt_long,
            color: AppColors.errorRed,
            bgColor: AppColors.pastelRed,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildStatCard(
            titleKey: 'Daily Total Amount (LKR)',
            value: dailyTotalAmount.toStringAsFixed(0),
            icon: Icons.payments,
            color: AppColors.primaryBlue,
            bgColor: AppColors.pastelBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String titleKey,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                PoliceText(
                  titleKey,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
