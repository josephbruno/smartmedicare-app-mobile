import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/device_token_service.dart';
import '../app_config.dart';
import '../desktop/desktop_prefs.dart';
import '../services/permission_service.dart';
import '../session/auth_session.dart';

// NOTE: Firebase (firebase_core / firebase_messaging) has been intentionally
// excluded from the Windows build because the precompiled Firebase C++ Windows
// SDK is ABI-incompatible with VS 2022 17.12 (unresolved __std_remove_8 /
// __std_find_last_of_trivial_pos_1 linker symbols).
// FCM is already gated to Android/iOS only at runtime; this stub preserves
// full Windows/desktop functionality via flutter_local_notifications.

typedef NotificationTapHandler = void Function(Map<String, dynamic> data);

/// Push + local notifications. Cashier visit alerts use desktop polling on Linux/Windows only.
class PushNotificationService {
  PushNotificationService({
    required DeviceTokenService deviceTokens,
    required AuthSession auth,
  })  : _deviceTokens = deviceTokens,
        _auth = auth;

  final DeviceTokenService _deviceTokens;
  final AuthSession _auth;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _currentToken;
  NotificationTapHandler? _onTap;
  final Set<int> _seenCompletedVisitIds = {};

  static const _visitChannel = AndroidNotificationChannel(
    'visit_billing',
    'Visit billing alerts',
    description: 'Notifications when a visit is ready for cashier billing',
    importance: Importance.high,
  );

  Future<void> initialize({NotificationTapHandler? onTap}) async {
    if (_initialized) return;
    _onTap = onTap;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const linuxInit = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );

    await _local.initialize(
      InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        linux: (Platform.isLinux || Platform.isWindows) ? linuxInit : null,
      ),
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload == null || payload.isEmpty) return;
        _handlePayload(payload);
      },
    );

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_visitChannel);
    }

    // FCM is only supported on Android/iOS. On Windows/Linux/macOS we rely on
    // visit polling + local notifications instead.
    if (_supportsFcm && !_auth.hasRole(AppRoles.cashier)) {
      await _initFcm();
    }

    _initialized = true;
    if (_auth.isAuthenticated) {
      await syncRegistration();
    }
  }

  bool get _supportsFcm =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get _cashierNotificationsEnabled =>
      _auth.hasRole(AppRoles.cashier) && AppConfig.isCashierPlatform;

  /// FCM initialisation — mobile only (Android / iOS).
  /// On Windows this method is never called (see [_supportsFcm]).
  Future<void> _initFcm() async {
    // Firebase is excluded from the Windows build.
    // On Android/iOS this would normally initialise firebase_messaging,
    // but we guard entry via [_supportsFcm] so this is only reached on mobile.
    // If you need FCM on mobile, re-add firebase_core & firebase_messaging to
    // pubspec.yaml (Windows is unaffected by those packages at the Dart level;
    // the issue is purely in the precompiled C++ Windows SDK).
    debugPrint('FCM init skipped on this platform (Firebase not linked).');
  }

  Future<void> syncRegistration() async {
    if (!_initialized || _auth.hasRole(AppRoles.cashier)) return;
    if (_currentToken != null) {
      await _registerToken(_currentToken!);
    }
  }

  Future<void> unregister() async {
    final token = _currentToken;
    if (token == null) return;
    try {
      await _deviceTokens.unregister(fcmToken: token);
    } catch (_) {}
  }

  Future<void> _registerToken(String token) async {
    if (!_auth.isAuthenticated || _auth.hasRole(AppRoles.cashier)) return;
    try {
      await _deviceTokens.register(
        fcmToken: token,
        platform: _platformName(),
        branchId: _auth.currentBranchId,
        deviceName: _deviceName(),
      );
    } catch (e) {
      debugPrint('Device token registration failed: $e');
    }
  }

  Future<void> showVisitReady({
    required int visitId,
    required String title,
    required String body,
  }) async {
    if (!_cashierNotificationsEnabled) return;

    final soundOn = await DesktopPrefs.getNotificationSound();
    if (soundOn) {
      SystemSound.play(SystemSoundType.alert);
    }

    await _showLocal(
      id: visitId,
      title: title,
      body: body,
      payload: _encodePayload({
        'type': 'visit_ready_for_billing',
        'visit_id': visitId.toString(),
      }),
    );
  }

  Future<void> _showLocal({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _local.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _visitChannel.id,
          _visitChannel.name,
          channelDescription: _visitChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
        linux: (Platform.isLinux || Platform.isWindows)
            ? const LinuxNotificationDetails(
                urgency: LinuxNotificationUrgency.normal,
              )
            : null,
      ),
      payload: payload,
    );
  }

  void _handlePayload(String payload) {
    final data = _decodePayload(payload);
    if (data.isNotEmpty) {
      _onTap?.call(data);
    }
  }

  void handleRouterNavigation(GoRouter router, Map<String, dynamic> data) {
    if (data['type'] == 'visit_ready_for_billing') {
      final visitId = data['visit_id']?.toString();
      if (visitId != null && visitId.isNotEmpty) {
        router.go('/pos?visit_id=$visitId');
      }
    }
  }

  void markVisitSeen(int visitId) => _seenCompletedVisitIds.add(visitId);

  bool shouldNotifyForVisit(int visitId) =>
      _cashierNotificationsEnabled && !_seenCompletedVisitIds.contains(visitId);

  String _platformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'web';
  }

  String _deviceName() {
    if (Platform.isAndroid) return 'Android device';
    if (Platform.isIOS) return 'iOS device';
    if (Platform.isWindows) return 'Windows desktop';
    if (Platform.isMacOS) return 'macOS desktop';
    if (Platform.isLinux) return 'Linux desktop';
    return 'Unknown device';
  }

  String _encodePayload(Map<String, dynamic> data) =>
      data.entries.map((e) => '${e.key}=${e.value}').join('&');

  Map<String, dynamic> _decodePayload(String payload) {
    final map = <String, dynamic>{};
    for (final part in payload.split('&')) {
      final idx = part.indexOf('=');
      if (idx <= 0) continue;
      map[part.substring(0, idx)] = part.substring(idx + 1);
    }
    return map;
  }

  void dispose() {}
}
