import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../controllers/liveness_detection_controller.dart';
import 'face_detector_painter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LivenessCameraView
// Drives the full liveness check and renders real-time step guidance.
//
// Flow: look → blink → turnLeft → turnRight → nodDown → nodUp → neutral → success
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
  // • enableClassification → eye-open probabilities (blink)
  // • performanceMode.accurate → head Euler angles (pitch / yaw)
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  // ── Liveness controller ────────────────────────────────────────────────────
  final LivenessDetectionController _livenessController =
      LivenessDetectionController();

  bool _isProcessing = false;
  bool _isCaptured   = false;

  // ── Arrow / hint animation ─────────────────────────────────────────────────
  late AnimationController _hintAnim;
  late Animation<double>   _hintOffset;

  // ── Step meta (label + icon per state) ────────────────────────────────────
  static const _stepMeta = [
    _StepMeta('Look',    Icons.visibility_outlined),
    _StepMeta('Blink',   Icons.remove_red_eye_outlined),
    _StepMeta('← Left',  Icons.arrow_back_rounded),
    _StepMeta('Right →', Icons.arrow_forward_rounded),
    _StepMeta('Nod ↓',   Icons.keyboard_arrow_down_rounded),
    _StepMeta('Nod ↑',   Icons.keyboard_arrow_up_rounded),
    _StepMeta('Neutral', Icons.face_outlined),
    _StepMeta('✓ Done',  Icons.check_circle_outline_rounded),
  ];

  int get _stepIndex {
    switch (_livenessController.state) {
      case LivenessState.look:      return 0;
      case LivenessState.blink:     return 1;
      case LivenessState.turnLeft:  return 2;
      case LivenessState.turnRight: return 3;
      case LivenessState.nodDown:   return 4;
      case LivenessState.nodUp:     return 5;
      case LivenessState.neutral:   return 6;
      case LivenessState.success:   return 7;
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _hintAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    _hintOffset = Tween<double>(begin: 0, end: 16).animate(
      CurvedAnimation(parent: _hintAnim, curve: Curves.easeInOut),
    );

    _livenessController.addListener(_onStateChange);
    _initializeCamera();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras     = await availableCameras();
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
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isNotEmpty) {
        _livenessController.processFace(faces.first);

        if (_livenessController.state == LivenessState.success && !_isCaptured) {
          _isCaptured = true;
          await _cameraController?.stopImageStream();
          // Small pause so the success icon is visible before capture
          await Future.delayed(const Duration(milliseconds: 700));
          await _captureSelfie();
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

  InputImage? _buildInputImage(CameraImage image) {
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
        size:        Size(image.width.toDouble(), image.height.toDouble()),
        rotation:    rotation,
        format:      format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _hintAnim.dispose();
    _livenessController
      ..removeListener(_onStateChange)
      ..dispose();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final state = _livenessController.state;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Camera feed ────────────────────────────────────────────────────
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _cameraController!.value.previewSize!.height,
              height: _cameraController!.value.previewSize!.width,
              child: CameraPreview(_cameraController!),
            ),
          ),
        ),

        // ── Face oval overlay ──────────────────────────────────────────────
        CustomPaint(
          painter: FaceDetectorPainter(
            imageSize: Size(
              _cameraController!.value.previewSize!.height,
              _cameraController!.value.previewSize!.width,
            ),
          ),
        ),

        // ── Step progress strip (top) ──────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildStepBar(),
        ),

        // ── Instruction banner ─────────────────────────────────────────────
        Positioned(
          top: 62,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Text(
              _livenessController.instruction,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),

        // ── Directional hint arrow ─────────────────────────────────────────
        Positioned(
          bottom: 90,
          left: 0,
          right: 0,
          child: _buildHintArrow(state),
        ),

        // ── Success icon ───────────────────────────────────────────────────
        if (state == LivenessState.success)
          const Center(
            child: Icon(
              Icons.check_circle_rounded,
              color: Colors.greenAccent,
              size: 120,
            ),
          ),
      ],
    );
  }

  // ── Animated directional hint arrow ───────────────────────────────────────
  Widget _buildHintArrow(LivenessState state) {
    // Map each state to an icon + animation axis
    IconData? icon;
    bool horizontal = false;
    bool reverseDir = false;

    switch (state) {
      case LivenessState.blink:
        icon = Icons.remove_red_eye_rounded;
        break;
      case LivenessState.turnLeft:
        icon = Icons.arrow_back_rounded;
        horizontal = true;
        reverseDir = true; // arrow moves left
        break;
      case LivenessState.turnRight:
        icon = Icons.arrow_forward_rounded;
        horizontal = true;
        break;
      case LivenessState.nodDown:
        icon = Icons.keyboard_arrow_down_rounded;
        break;
      case LivenessState.nodUp:
        icon = Icons.keyboard_arrow_up_rounded;
        reverseDir = true; // arrow moves up
        break;
      case LivenessState.neutral:
        icon = Icons.face_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _hintOffset,
      builder: (_, __) {
        final double v = reverseDir ? -_hintOffset.value : _hintOffset.value;
        final Offset shift = horizontal ? Offset(v, 0) : Offset(0, v);

        return Transform.translate(
          offset: shift,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.88), size: 60),
              const SizedBox(height: 6),
              Text(
                _hintLabel(state),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _hintLabel(LivenessState state) {
    switch (state) {
      case LivenessState.blink:     return 'Close your eyes';
      case LivenessState.turnLeft:  return 'Turn left';
      case LivenessState.turnRight: return 'Turn right';
      case LivenessState.nodDown:   return 'Chin down';
      case LivenessState.nodUp:     return 'Raise head';
      case LivenessState.neutral:   return 'Hold still';
      default:                      return '';
    }
  }

  // ── Step progress bar ──────────────────────────────────────────────────────
  Widget _buildStepBar() {
    final stepIdx = _stepIndex;

    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      child: Row(
        children: List.generate(_stepMeta.length, (i) {
          final bool done    = i < stepIdx;
          final bool current = i == stepIdx;
          final meta         = _stepMeta[i];

          return Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width:  current ? 26 : 18,
                  height: current ? 26 : 18,
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
                        ? const Icon(Icons.check, size: 12, color: Colors.black87)
                        : Icon(
                            meta.icon,
                            size: current ? 14 : 10,
                            color: current ? Colors.black87 : Colors.white38,
                          ),
                  ),
                ),
                // Connector (skip last)
                if (i < _stepMeta.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
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

// ── Helper record ──────────────────────────────────────────────────────────────
class _StepMeta {
  final String   label;
  final IconData icon;
  const _StepMeta(this.label, this.icon);
}
