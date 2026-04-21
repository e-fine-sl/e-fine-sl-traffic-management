import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final prefs = await SharedPreferences.getInstance();
    final timeoutMinutes = prefs.getInt(PrefKeys.idleTimeoutMinutes) ?? 5;
    
    if (timeoutMinutes <= 0) return; // Feature disabled or not logged in

    final now = DateTime.now();
    final difference = now.difference(_lastInteraction).inMinutes;

    if (difference >= timeoutMinutes) {
      debugPrint('[InteractionListener] IDLE TIMEOUT REACHED ($difference min). Logging out...');
      _handleLogout();
    }
  }

  Future<void> _handleLogout() async {
    _timer?.cancel();
    
    // 1. Perform logout (clears tokens and notifies server)
    await _authService.logout();

    // 2. Clear last interaction to prevent repeat triggers
    _lastInteraction = DateTime.now().subtract(const Duration(days: 1));

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
