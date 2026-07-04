// ─────────────────────────────────────────────────────────────────────────────
// lib/widgets/otp_input_field.dart
// Reusable 6-digit OTP input widget for e-Fine SL
// Used in: EmailVerificationScreen, ForgotPasswordScreen
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_constants.dart';

class OtpInputField extends StatefulWidget {
  /// Number of OTP digits (default 6)
  final int length;

  /// Called when all digits are entered
  final ValueChanged<String>? onCompleted;

  /// Called on every change with current partial value
  final ValueChanged<String>? onChanged;

  /// Accent color for the active/filled box border
  final Color accentColor;

  /// Background color for filled boxes
  final Color filledBackground;

  const OtpInputField({
    super.key,
    this.length = 6,
    this.onCompleted,
    this.onChanged,
    this.accentColor = AppColors.primaryGreen,
    this.filledBackground = const Color(0xFFE8F5E9), // pastelGreen
  });

  @override
  State<OtpInputField> createState() => OtpInputFieldState();
}

class OtpInputFieldState extends State<OtpInputField> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  /// Public method to clear all OTP fields (useful for retry/resend)
  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    if (_focusNodes.isNotEmpty) {
      _focusNodes[0].requestFocus();
    }
  }

  /// Get the current OTP string
  String get currentOtp => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste: distribute characters across boxes
      final chars = value.split('');
      for (int i = 0; i < chars.length && (index + i) < widget.length; i++) {
        _controllers[index + i].text = chars[i];
      }
      final lastIndex = (index + chars.length - 1).clamp(0, widget.length - 1);
      if (lastIndex < widget.length - 1) {
        _focusNodes[lastIndex + 1].requestFocus();
      } else {
        _focusNodes[lastIndex].unfocus();
      }
    } else if (value.isNotEmpty) {
      // Single character typed — move to next box
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }

    // Notify listeners
    final otp = currentOtp;
    widget.onChanged?.call(otp);

    if (otp.length == widget.length) {
      widget.onCompleted?.call(otp);
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (index) {
        final hasValue = _controllers[index].text.isNotEmpty;

        return Container(
          width: 48,
          height: 56,
          margin: EdgeInsets.symmetric(
            horizontal: index == widget.length - 1 ? 0 : 5,
          ),
          child: KeyboardListener(
            focusNode: FocusNode(), // wrapper focus node for key events
            onKeyEvent: (event) => _onKeyEvent(index, event),
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                counterText: '', // Hide the "0/1" counter
                filled: true,
                fillColor: hasValue
                    ? widget.filledBackground.withValues(alpha: isDark ? 0.2 : 1.0)
                    : (isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  borderSide: BorderSide(
                    color: Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  borderSide: BorderSide(
                    color: hasValue
                        ? widget.accentColor.withValues(alpha: 0.6)
                        : Colors.grey.shade300,
                    width: hasValue ? 2.0 : 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  borderSide: BorderSide(
                    color: widget.accentColor,
                    width: 2.5,
                  ),
                ),
              ),
              onChanged: (value) => _onChanged(index, value),
              onTap: () {
                // Select all text on tap for easy replacement
                _controllers[index].selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _controllers[index].text.length,
                );
              },
            ),
          ),
        );
      }),
    );
  }
}
