// ─────────────────────────────────────────────────────────────────────────────
// lib/controllers/liveness_detection_controller.dart
// e-Fine SL — Liveness Detection State Machine
//
// Flow: look → blink → turnLeft → turnRight → nodDown → nodUp → neutral → success
//
//  • look      : face detected — user is present
//  • blink     : both eyes close  (eyeOpenProbability < eyeClosedThreshold)
//  • turnLeft  : face turns left  (headEulerAngleY < -yawThreshold)
//  • turnRight : face turns right (headEulerAngleY >  yawThreshold)
//  • nodDown   : chin drops down  (headEulerAngleX < nodDownThreshold)
//  • nodUp     : head raises back (headEulerAngleX > nodUpThreshold)
//  • neutral   : face level & centred for 500 ms → auto-capture
//  • success   : verification complete
//
// ML Kit head angles (front camera, standard coordinates):
//   headEulerAngleX (pitch): negative = chin down, positive = chin up
//   headEulerAngleY (yaw) : negative = turned left, positive = turned right
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum LivenessState {
  look,
  blink,
  turnLeft,
  turnRight,
  nodDown,
  nodUp,
  neutral,
  success,
}

class LivenessDetectionController extends ChangeNotifier {
  LivenessState _state       = LivenessState.look;
  String        _instruction = 'Please look at the camera';

  // ── Blink ──────────────────────────────────────────────────────────────────
  /// Eye-open probability below which the eye is considered closed.
  static const double eyeClosedThreshold = 0.25;

  // ── Turn (yaw, headEulerAngleY) ────────────────────────────────────────────
  /// Face must exceed this yaw (°) to register a turn.
  static const double yawThreshold = 18.0;

  // ── Nod (pitch, headEulerAngleX) ───────────────────────────────────────────
  /// Chin must drop below this pitch (°) to register a down-nod.
  static const double nodDownThreshold = -12.0;

  /// Head must recover above this pitch (°) to register the up-recovery.
  static const double nodUpThreshold   = -3.0;

  // ── Neutral hold ───────────────────────────────────────────────────────────
  /// Pitch must be within ±5° and yaw within ±8° to be considered neutral.
  static const double neutralPitchMax = 5.0;
  static const double neutralYawMax   = 8.0;

  /// How many consecutive neutral frames are required before capturing.
  static const int    neutralFramesRequired = 6;
  int _neutralFrameCount = 0;

  // ── Public getters ──────────────────────────────────────────────────────────
  LivenessState get state       => _state;
  String        get instruction => _instruction;

  // ── Main processing entry-point ─────────────────────────────────────────────
  void processFace(Face face) {
    if (_state == LivenessState.success) return;

    final double leftEye  = face.leftEyeOpenProbability  ?? 1.0;
    final double rightEye = face.rightEyeOpenProbability ?? 1.0;
    final double pitch    = face.headEulerAngleX          ?? 0.0; // up/down
    final double yaw      = face.headEulerAngleY          ?? 0.0; // left/right

    switch (_state) {

      // ── Step 0: Wait for a face ─────────────────────────────────────────────
      case LivenessState.look:
        _updateState(
          LivenessState.blink,
          'Blink your eyes 👁',
        );
        break;

      // ── Step 1: Blink ───────────────────────────────────────────────────────
      case LivenessState.blink:
        if (leftEye < eyeClosedThreshold || rightEye < eyeClosedThreshold) {
          _updateState(
            LivenessState.turnLeft,
            'Turn your head to the LEFT ←',
          );
        }
        break;

      // ── Step 2: Turn Left ───────────────────────────────────────────────────
      // When user turns left, yaw becomes positive
      case LivenessState.turnLeft:
        if (yaw > yawThreshold) {
          _updateState(
            LivenessState.turnRight,
            'Now turn your head to the RIGHT →',
          );
        }
        break;

      // ── Step 3: Turn Right ──────────────────────────────────────────────────
      // When user turns right, yaw becomes negative
      case LivenessState.turnRight:
        if (yaw < -yawThreshold) {
          _updateState(
            LivenessState.nodDown,
            'Face forward, then nod your head DOWN ↓',
          );
        }
        break;

      // ── Step 4: Nod Down ────────────────────────────────────────────────────
      case LivenessState.nodDown:
        if (pitch < nodDownThreshold) {
          _updateState(
            LivenessState.nodUp,
            'Now raise your head back UP ↑',
          );
        }
        break;

      // ── Step 5: Nod Up ──────────────────────────────────────────────────────
      case LivenessState.nodUp:
        if (pitch > nodUpThreshold) {
          _neutralFrameCount = 0;
          _updateState(
            LivenessState.neutral,
            'Hold still — face forward 🙂',
          );
        }
        break;

      // ── Step 6: Neutral hold before capture ────────────────────────────────
      case LivenessState.neutral:
        final bool isNeutral =
            pitch.abs() < neutralPitchMax && yaw.abs() < neutralYawMax;

        if (isNeutral) {
          _neutralFrameCount++;
          if (_neutralFrameCount >= neutralFramesRequired) {
            _updateState(
              LivenessState.success,
              '✓  Liveness Verified!',
            );
          }
        } else {
          // Reset count if they move away
          _neutralFrameCount = 0;
        }
        break;

      case LivenessState.success:
        break;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  void _updateState(LivenessState newState, String newInstruction) {
    _state             = newState;
    _instruction       = newInstruction;
    _neutralFrameCount = 0;
    notifyListeners();
  }

  void reset() {
    _neutralFrameCount = 0;
    _updateState(LivenessState.look, 'Please look at the camera');
  }


}
