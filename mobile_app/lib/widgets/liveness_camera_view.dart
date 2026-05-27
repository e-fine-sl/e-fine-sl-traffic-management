import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../controllers/liveness_detection_controller.dart';
import 'face_detector_painter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LivenessCameraView
// Renders the front camera, draws a face-oval overlay, shows an instruction
// banner, and drives LivenessDetectionController.
//
// Liveness flow: look → blink → nodDown → nodUp → success
// ─────────────────────────────────────────────────────────────────────────────

class LivenessCameraView extends StatefulWidget {
  /// Called with the captured selfie File once all checks pass.
  final Function(File capturedFile) onCompleted;

  /// Optional error callback.
  final Function(String error)? onError;

  const LivenessCameraView({
    super.key,
    required this.onCompleted,
    this.onError,
  });

  @override
  State<LivenessCameraView> createState() => _LivenessCameraViewState();
}

class _LivenessCameraViewState extends State<LivenessCameraView>
    with SingleTickerProviderStateMixin {
  // ── Camera ─────────────────────────────────────────────────────────────────
  CameraController? _cameraController;

  // ── ML Kit Face Detector ───────────────────────────────────────────────────
  // enableClassification  → eye-open probabilities (blink detection)
  // performanceMode.accurate → also returns head Euler angles (pitch = X)
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,       // eye-open probability
      performanceMode: FaceDetectorMode.accurate, // head euler angles
    ),
  );

  // ── Liveness ───────────────────────────────────────────────────────────────
  final LivenessDetectionController _livenessController =
      LivenessDetectionController();

  bool _isProcessing = false;
  bool _isCaptured   = false;

  // ── Nod arrow animation ────────────────────────────────────────────────────
  late AnimationController _arrowAnim;
  late Animation<double>   _arrowOffset;

  // ── Step labels (synced to LivenessState) ─────────────────────────────────
  static const _steps = ['Look', 'Blink', 'Nod ↓', 'Nod ↑', '✓'];

  int get _currentStepIndex {
    switch (_livenessController.state) {
      case LivenessState.look:     return 0;
      case LivenessState.blink:    return 1;
      case LivenessState.nodDown:  return 2;
      case LivenessState.nodUp:    return 3;
      case LivenessState.success:  return 4;
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Bounce animation for the nod-down / nod-up arrow hint
    _arrowAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _arrowOffset = Tween<double>(begin: 0, end: 14).animate(
      CurvedAnimation(parent: _arrowAnim, curve: Curves.easeInOut),
    );

    _livenessController.addListener(_onLivenessStateChange);
    _initializeCamera();
  }

  void _onLivenessStateChange() {
    if (!mounted) return;
    setState(() {}); // redraw step indicator & instruction banner
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras    = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController?.initialize();
      if (!mounted) return;

      _cameraController?.startImageStream(_processCameraImage);
      setState(() {});
    } catch (e) {
      widget.onError?.call('Failed to initialize camera: $e');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || _isCaptured || !mounted) return;
    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        _livenessController.processFace(faces.first);

        if (_livenessController.state == LivenessState.success && !_isCaptured) {
          _isCaptured = true;
          await _cameraController?.stopImageStream();
          await Future.delayed(const Duration(milliseconds: 600)); // show ✓ icon
          _captureSelfie();
        }
      }
    } catch (e) {
      debugPrint('[Liveness] Frame error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _captureSelfie() async {
    try {
      final XFile file = await _cameraController!.takePicture();
      widget.onCompleted(File(file.path));
    } catch (e) {
      widget.onError?.call('Failed to capture picture: $e');
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    final sensorOrientation = _cameraController!.description.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS    && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size:         Size(image.width.toDouble(), image.height.toDouble()),
        rotation:     rotation,
        format:       format,
        bytesPerRow:  plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _arrowAnim.dispose();
    _livenessController.removeListener(_onLivenessStateChange);
    _cameraController?.dispose();
    _faceDetector.close();
    _livenessController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final state = _livenessController.state;
    final isNodStep = state == LivenessState.nodDown || state == LivenessState.nodUp;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Camera feed ────────────────────────────────────────────────────
        CameraPreview(_cameraController!),

        // ── Oval overlay ───────────────────────────────────────────────────
        CustomPaint(
          painter: FaceDetectorPainter(
            imageSize: Size(
              _cameraController!.value.previewSize!.height,
              _cameraController!.value.previewSize!.width,
            ),
          ),
        ),

        // ── Step progress bar (top strip) ──────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildStepBar(),
        ),

        // ── Instruction banner ─────────────────────────────────────────────
        Positioned(
          top: 58,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.60),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              _livenessController.instruction,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // ── Animated nod arrow hint ────────────────────────────────────────
        if (isNodStep)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _arrowOffset,
              builder: (_, __) {
                final offsetY = state == LivenessState.nodDown
                    ? _arrowOffset.value    // bounces downward
                    : -_arrowOffset.value;  // bounces upward
                return Transform.translate(
                  offset: Offset(0, offsetY),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state == LivenessState.nodDown
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        color: Colors.white.withValues(alpha: 0.85),
                        size: 64,
                      ),
                      Text(
                        state == LivenessState.nodDown
                            ? 'Nod chin down'
                            : 'Raise head up',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        // ── Success tick ───────────────────────────────────────────────────
        if (state == LivenessState.success)
          const Center(
            child: Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 110),
          ),
      ],
    );
  }

  // ── Step progress bar widget ───────────────────────────────────────────────
  Widget _buildStepBar() {
    final stepIdx = _currentStepIndex;

    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_steps.length, (i) {
          final bool done    = i < stepIdx;
          final bool current = i == stepIdx;

          return Expanded(
            child: Row(
              children: [
                // ── Circle dot ─────────────────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width:  current ? 28 : 20,
                  height: current ? 28 : 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? Colors.greenAccent
                        : current
                            ? Colors.white
                            : Colors.white24,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check, size: 14, color: Colors.black87)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: current ? 13 : 11,
                              fontWeight: FontWeight.bold,
                              color: current ? Colors.black87 : Colors.white54,
                            ),
                          ),
                  ),
                ),
                // ── Label ──────────────────────────────────────────────────
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _steps[i],
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: done
                          ? Colors.greenAccent
                          : current
                              ? Colors.white
                              : Colors.white38,
                      fontSize: current ? 12 : 10,
                      fontWeight: current ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                // ── Connector line (skip last) ──────────────────────────────
                if (i < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: i < stepIdx ? Colors.greenAccent : Colors.white24,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
