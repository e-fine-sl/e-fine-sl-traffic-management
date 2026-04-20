import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../controllers/liveness_detection_controller.dart';
import 'face_detector_painter.dart';

class LivenessCameraView extends StatefulWidget {
  final Function(File capturedFile) onCompleted;
  final Function(String error)? onError;

  const LivenessCameraView({
    super.key,
    required this.onCompleted,
    this.onError,
  });

  @override
  State<LivenessCameraView> createState() => _LivenessCameraViewState();
}

class _LivenessCameraViewState extends State<LivenessCameraView> {
  CameraController? _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  final LivenessDetectionController _livenessController = LivenessDetectionController();
  bool _isProcessing = false;
  bool _isCaptured = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
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
      widget.onError?.call("Failed to initialize camera: $e");
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
          _cameraController?.stopImageStream();
          _captureSelfie();
        }
      }
    } catch (e) {
      debugPrint("Face detection error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _captureSelfie() async {
    try {
      final XFile file = await _cameraController!.takePicture();
      widget.onCompleted(File(file.path));
    } catch (e) {
      widget.onError?.call("Failed to capture picture: $e");
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;
    
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    _livenessController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),
        
        // Oval Overlay
        CustomPaint(
          painter: FaceDetectorPainter(
            imageSize: Size(
              _cameraController!.value.previewSize!.height,
              _cameraController!.value.previewSize!.width,
            ),
          ),
        ),

        // Instructions
        Positioned(
          top: 50,
          left: 20,
          right: 20,
          child: ListenableBuilder(
            listenable: _livenessController,
            builder: (context, _) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  _livenessController.instruction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ),

        // Result / Success Indicator
        if (_livenessController.state == LivenessState.success)
          const Center(
            child: Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 100,
            ),
          ),
      ],
    );
  }
}
