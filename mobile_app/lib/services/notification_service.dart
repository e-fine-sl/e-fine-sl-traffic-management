import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Singleton service for managing device notification bar alerts.
class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _prefKey = 'notifications_enabled';
  bool _initialized = false;
  bool _enabled = false;

  bool get isEnabled => _enabled;

  // ── Initialization ────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request permissions for Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Load persisted preference
    final stored = await _storage.read(key: _prefKey);
    _enabled = stored == null ? true : stored == 'true'; // default ON

    _initialized = true;
    debugPrint('[NotificationService] Initialized — enabled=$_enabled');
  }

  // ── Preference ────────────────────────────────────────
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _storage.write(key: _prefKey, value: value.toString());
    debugPrint('[NotificationService] Notifications ${value ? "ON" : "OFF"}');

    if (!value) {
      // Cancel any pending notifications when disabled
      await _plugin.cancelAll();
    }
  }

  // ── Show a fine notification ─────────────────────────
  Future<void> showFineNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    if (!_enabled) return;

    const androidDetails = AndroidNotificationDetails(
      'efine_fines_channel', // channel ID
      'Traffic Fines', // channel name
      channelDescription: 'Notifications for new traffic fines',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(id, title, body, details);
    debugPrint('[NotificationService] Showed notification: $title');
  }

  // ── Show a HIGH-PRIORITY accident alert notification ─────────────
  Future<void> showAccidentNotification({
    required String title,
    required String body,
    String? payload,
    int id = 999,
  }) async {
    // Show regardless of _enabled preference — safety alerts always show
    
    const androidDetails = AndroidNotificationDetails(
      'accident_alerts_channel',          // channel ID — distinct from fines
      'Accident Alerts',                  // channel name
      channelDescription: 'Real-time accident alerts for nearby incidents',
      importance: Importance.max,         // Highest possible
      priority: Priority.max,             // Highest possible
      icon: '@mipmap/launcher_icon',
      color: Color(0xFFD32F2F),           // Red
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(<int>[0, 500, 250, 500, 250, 500]),
      fullScreenIntent: true,             // Shows even on lock screen
      styleInformation: BigTextStyleInformation(
        '',
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
      ),
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(id, title, body, details, payload: payload);
    debugPrint('[NotificationService] [Accident] Showed ACCIDENT notification: $title');
  }

  // ── Tap handler ───────────────────────────────────────
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('[NotificationService] Notification tapped: ${response.payload}');
    // Can navigate to pay-fine screen via a global navigator key in the future
  }
}
