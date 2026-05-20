import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_constants.dart';
import '../services/auth_service.dart';

/// A wrapper widget that monitors user interactions and app lifecycle
/// to handle session timeouts.
class InteractionListener extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const InteractionListener({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<InteractionListener> createState() => _InteractionListenerState();
}

class _InteractionListenerState extends State<InteractionListener> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _lastInteraction = DateTime.now();
  final AuthService _authService = AuthService();
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User returned to the app - check if they timed out while in background
      debugPrint('[InteractionListener] App resumed. Checking background timeout...');
      _checkTimeout();
    }
  }

  Future<void> _startTimer() async {
    _timer?.cancel();
    
    // We check every 30 seconds if the timeout has been reached
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkTimeout();
    });
  }

  Future<void> _checkTimeout() async {
    final token = await _storage.read(key: PrefKeys.accessToken);
    if (token == null) return; 

    // 1. 2-Day Session Expiration Check
    final startTimeStr = await _storage.read(key: PrefKeys.sessionStartTime);
    if (startTimeStr != null) {
      try {
        final startTime = DateTime.parse(startTimeStr);
        final difference = DateTime.now().difference(startTime);
        if (difference.inDays >= 2) {
          debugPrint('[InteractionListener] 2-Day Session Expired. Logging out...');
          await _handleLogout();
          return;
        }
      } catch (e) {
        debugPrint('[InteractionListener] Error parsing session start time: $e');
      }
    }

    // 2. Idle Timeout Check (if enabled)
    final prefs = await SharedPreferences.getInstance();
    final timeoutMinutes = prefs.getInt(PrefKeys.idleTimeoutMinutes) ?? 0;
    
    if (timeoutMinutes <= 0) return; 

    final now = DateTime.now();
    final difference = now.difference(_lastInteraction).inMinutes;

    if (difference >= timeoutMinutes) {
      debugPrint('[InteractionListener] IDLE TIMEOUT REACHED ($difference min). Logging out...');
      await _handleLogout();
    }
  }

  Future<void> _handleLogout() async {
    // DO NOT cancel the timer here, as InteractionListener wraps the whole app.
    // If we cancel it, it won't restart when the user logs back in!
    
    // 1. Perform logout (clears tokens and notifies server)
    await _authService.logout();

    // 2. Reset last interaction to prevent repeat triggers
    _lastInteraction = DateTime.now();

    // 3. Navigate to login screen
    if (widget.navigatorKey.currentState != null) {
      widget.navigatorKey.currentState!.pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  void _onInteraction([dynamic _]) {
    // Reset the interaction timestamp
    _lastInteraction = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onInteraction,
      onPointerMove: _onInteraction,
      onPointerUp: _onInteraction,
      child: widget.child,
    );
  }
}
