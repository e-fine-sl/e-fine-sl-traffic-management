// ─────────────────────────────────────────────────────────────────────────────
// lib/controllers/liveness_detection_controller.dart
// e-Fine SL — Liveness Detection State Machine
//
// Flow: look → blink → smile → neutral → success
// Captures photo when user returns to neutral expression after smiling
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum LivenessState { look, blink, smile, neutral, success }

class LivenessDetectionController extends ChangeNotifier {
  LivenessState _state = LivenessState.look;
  String _instruction = "Please look at the camera";

  // Configurable thresholds
  static const double eyeOpenThreshold = 0.2;    // Eyes closed when < 0.2
  static const double smileThreshold = 0.7;      // Smiling when > 0.7
  static const double neutralThreshold = 0.3;    // Neutral when < 0.3

  LivenessState get state => _state;
  String get instruction => _instruction;

  void processFace(Face face) {
    if (_state == LivenessState.success) return;

    switch (_state) {
      case LivenessState.look:
        // Transition to blink once a face is detected
        _updateState(LivenessState.blink, "Please blink your eyes");
        break;

      case LivenessState.blink:
        final leftEyeProb = face.leftEyeOpenProbability ?? 1.0;
        final rightEyeProb = face.rightEyeOpenProbability ?? 1.0;

        // Detect eye closure
        if (leftEyeProb < eyeOpenThreshold || rightEyeProb < eyeOpenThreshold) {
          _updateState(LivenessState.smile, "Perfect! Now give us a big smile");
        }
        break;

      case LivenessState.smile:
        final smileProb = face.smilingProbability ?? 0.0;

        // Detect smile
        if (smileProb > smileThreshold) {
          _updateState(LivenessState.neutral, "Great! Now return to a neutral expression");
        }
        break;

      case LivenessState.neutral:
        final smileProb = face.smilingProbability ?? 0.0;

        // Capture when user returns to neutral (not smiling)
        if (smileProb < neutralThreshold) {
          _updateState(LivenessState.success, "Perfect! Verification Complete!");
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
