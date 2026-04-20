import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum LivenessState { look, blink, smile, success }

class LivenessDetectionController extends ChangeNotifier {
  LivenessState _state = LivenessState.look;
  String _instruction = "Please look at the camera";

  // Configurable thresholds
  static const double eyeOpenThreshold = 0.2;
  static const double smileThreshold = 0.7;

  LivenessState get state => _state;
  String get instruction => _instruction;

  void processFace(Face face) {
    if (_state == LivenessState.success) return;

    switch (_state) {
      case LivenessState.look:
        // Transition to blink once a face is detected (implicit in processFace being called)
        _updateState(LivenessState.blink, "Please blink your eyes");
        break;

      case LivenessState.blink:
        final leftEyeProb = face.leftEyeOpenProbability ?? 1.0;
        final rightEyeProb = face.rightEyeOpenProbability ?? 1.0;

        if (leftEyeProb < eyeOpenThreshold || rightEyeProb < eyeOpenThreshold) {
          _updateState(LivenessState.smile, "Perfect! Now give us a big smile");
        }
        break;

      case LivenessState.smile:
        final smileProb = face.smilingProbability ?? 0.0;

        if (smileProb > smileThreshold) {
          _updateState(LivenessState.success, "Verification Complete!");
        }
        break;

      case LivenessState.success:
        break;
    }
  }

  void _updateState(LivenessState newState, String newInstruction) {
    _state = newState;
    _instruction = newInstruction;
    notifyListeners();
  }

  void reset() {
    _updateState(LivenessState.look, "Please look at the camera");
  }
}
