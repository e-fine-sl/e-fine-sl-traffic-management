// ─────────────────────────────────────────────────────────────────────────────
// lib/controllers/liveness_detection_controller.dart
// e-Fine SL — Liveness Detection State Machine
//
// Flow: look → blink → nodDown → nodUp → success
//  • look    : face detected — confirm user is present
//  • blink   : both eyes must close (eye-open probability drops below threshold)
//  • nodDown : user nods chin down (headEulerAngleX goes negative, < nodDownThreshold)
//  • nodUp   : user raises head back to level (headEulerAngleX returns > nodUpThreshold)
//  • success : photo captured automatically
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum LivenessState { look, blink, nodDown, nodUp, success }

class LivenessDetectionController extends ChangeNotifier {
  LivenessState _state = LivenessState.look;
  String _instruction  = 'Please look at the camera';

  // ── Eye blink thresholds ────────────────────────────────────────────────────
  /// Probability below which an eye is considered closed.
  static const double eyeClosedThreshold = 0.25;

  // ── Head-nod thresholds (headEulerAngleX / pitch) ───────────────────────────
  // Positive X → head tilted up (chin raised)
  // Negative X → head tilted down (chin tucked)
  /// Chin must drop below this angle (degrees) to register a down-nod.
  static const double nodDownThreshold = -12.0;

  /// Head must return above this angle (degrees) to register the up-recovery.
  static const double nodUpThreshold   = -3.0;

  // ── Public getters ──────────────────────────────────────────────────────────
  LivenessState get state       => _state;
  String        get instruction => _instruction;

  // ── Main processing entry-point ─────────────────────────────────────────────
  void processFace(Face face) {
    if (_state == LivenessState.success) return;

    final double leftEye  = face.leftEyeOpenProbability  ?? 1.0;
    final double rightEye = face.rightEyeOpenProbability ?? 1.0;
    final double pitch    = face.headEulerAngleX         ?? 0.0;

    switch (_state) {

      // ── Step 0: Wait for a face to appear ──────────────────────────────────
      case LivenessState.look:
        _updateState(
          LivenessState.blink,
          'Great! Now blink your eyes',
        );
        break;

      // ── Step 1: Detect eye blink ────────────────────────────────────────────
      case LivenessState.blink:
        if (leftEye < eyeClosedThreshold || rightEye < eyeClosedThreshold) {
          _updateState(
            LivenessState.nodDown,
            'Nice! Now slowly nod your head down ⬇',
          );
        }
        break;

      // ── Step 2: Detect chin-down nod ────────────────────────────────────────
      case LivenessState.nodDown:
        if (pitch < nodDownThreshold) {
          _updateState(
            LivenessState.nodUp,
            'Perfect! Now raise your head back up ⬆',
          );
        }
        break;

      // ── Step 3: Detect head returning to level ──────────────────────────────
      case LivenessState.nodUp:
        if (pitch > nodUpThreshold) {
          _updateState(
            LivenessState.success,
            '✓  Liveness Verified!',
          );
        }
        break;

      case LivenessState.success:
        break;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  void _updateState(LivenessState newState, String newInstruction) {
    _state       = newState;
    _instruction = newInstruction;
    notifyListeners();
  }

  void reset() {
    _updateState(LivenessState.look, 'Please look at the camera');
  }

  @override
  void dispose() {
    // No resources to close; kept for symmetry with ChangeNotifier pattern.
    super.dispose();
  }
}
