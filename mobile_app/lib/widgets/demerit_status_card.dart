import 'dart:math';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../config/app_constants.dart';

// ---------------------------------------------------------------------------
// CustomPainter — 300° gauge arc (speedometer style)
// ---------------------------------------------------------------------------
class _GaugeArcPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  final Color arcColor;
  final Color trackColor;

  _GaugeArcPainter({required this.progress, required this.arcColor, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;

    const double sweepTotal = 300 * pi / 180; // 300°
    const double startAngle = 120 * pi / 180; // bottom-left start

    // Background track
    final bgPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      bgPaint,
    );

    // Foreground (filled) arc
    if (progress > 0) {
      final fgPaint = Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepTotal * progress,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugeArcPainter old) =>
      old.progress != progress || old.arcColor != arcColor || old.trackColor != trackColor;
}

// ---------------------------------------------------------------------------
// DemeritStatusCard — gauge version with localization
// ---------------------------------------------------------------------------
class DemeritStatusCard extends StatefulWidget {
  final int points;            // 0–100
  final int maxPoints;         // Default max ceiling (e.g. 24 or 26)
  final String status;         // 'ACTIVE' or 'SUSPENDED'
  final DateTime? suspendedAt;

  const DemeritStatusCard({
    required this.points,
    this.maxPoints = DemeritConstants.defaultPoints,
    required this.status,
    this.suspendedAt,
    super.key,
  });

  @override
  State<DemeritStatusCard> createState() => _DemeritStatusCardState();
}

class _DemeritStatusCardState extends State<DemeritStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  int get _maxPoints => widget.maxPoints <= 0 ? DemeritConstants.defaultPoints : widget.maxPoints;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(
      begin: 0.0, 
      end: (widget.points / _maxPoints).clamp(0.0, 1.0)
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant DemeritStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points || oldWidget.maxPoints != widget.maxPoints) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: (widget.points / _maxPoints).clamp(0.0, 1.0),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // -- Color helper based on points --
  Color _getStatusColor(int pts) => DemeritLevel.getColor(pts, _maxPoints);

  // -- Localized label helper based on points --
  String _getStatusLabel(int pts) {
    if (pts <= 0) return 'demerit_suspended'.tr();
    return DemeritLevel.getLabel(pts, _maxPoints).tr();
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  double _calculateRatingPoints(int points) {
    final max = _maxPoints.toDouble();
    final rating = (points / max) * 5.0;
    return double.parse(rating.clamp(0.0, 5.0).toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    final bool isSuspended = widget.status == AppStatus.suspended || widget.points <= 0;
    final Color color = isSuspended ? AppColors.errorRed : _getStatusColor(widget.points);
    final String label = isSuspended
        ? 'demerit_suspended'.tr()
        : _getStatusLabel(widget.points);
    final ratingPoints = _calculateRatingPoints(widget.points);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Title ──────────────────────────────────────
            Text(
              'demerit_title'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),

            const SizedBox(height: 20),

            // ── Gauge circle ───────────────────────────────
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                final displayPts = (_animation.value * _maxPoints).round();
                final animColor = isSuspended ? AppColors.errorRed : _getStatusColor(displayPts);
                return SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(180, 180),
                        painter: _GaugeArcPainter(
                          progress: _animation.value,
                          arcColor: animColor,
                          trackColor: AppTheme.gaugeTrack(context),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${widget.points} / $_maxPoints',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: animColor,
                            ),
                          ),
                          Text(
                            'demerit_points_label'.tr(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // ── Status label ───────────────────────────────
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 4),
            Text(
              'demerit_rating_points'.tr(args: [ratingPoints.toStringAsFixed(1)]),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary(context),
              ),
            ),

            // ── Suspended date ─────────────────────────────
            if (widget.status == AppStatus.suspended &&
                widget.suspendedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'demerit_suspended_on'.tr(args: [_formatDate(widget.suspendedAt!)]),
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
              ),
            ],

            // ── Reinstatement info banner ───────────────────
            if (widget.status == AppStatus.suspended) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.errorRed, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'demerit_reinstate_info'.tr(),
                        style: const TextStyle(fontSize: 12, color: AppColors.errorRed),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
