import 'package:flutter/material.dart';

class FaceDetectorPainter extends CustomPainter {
  final Rect? faceRect;
  final Size imageSize;
  final bool isReflection;

  FaceDetectorPainter({
    required this.imageSize,
    this.faceRect,
    this.isReflection = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the guiding oval
    final Paint ovalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.white.withAlpha(128); // 0.5 * 255 approx 128

    final double ovalWidth = size.width * 0.7;
    final double ovalHeight = size.height * 0.6;
    final Rect guidingOval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: ovalWidth,
      height: ovalHeight,
    );

    // Semi-transparent background with a hole for the oval
    final Paint backgroundPaint = Paint()..color = Colors.black.withAlpha(102); // 0.4 * 255 approx 102
    final Path backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path ovalPath = Path()..addOval(guidingOval);
    final Path finalPath = Path.combine(PathOperation.difference, backgroundPath, ovalPath);
    canvas.drawPath(finalPath, backgroundPaint);

    // Draw the oval border
    canvas.drawOval(guidingOval, ovalPaint);

    // If a face is detected and within the oval, change border color to green
    if (faceRect != null) {
      final Paint detectedPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.green;

      // Check if face is roughly centered in the oval
      // (Optional: can be more strict if desired)
      canvas.drawOval(guidingOval, detectedPaint);
    }
  }

  @override
  bool shouldRepaint(covariant FaceDetectorPainter oldDelegate) {
    return oldDelegate.faceRect != faceRect || oldDelegate.imageSize != imageSize;
  }
}
