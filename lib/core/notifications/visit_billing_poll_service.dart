import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app_config.dart';
import '../../data/services/emr_service.dart';
import '../notifications/push_notification_service.dart';
import '../services/permission_service.dart';
import '../session/auth_session.dart';

/// Polls for completed visits on desktop/Linux when FCM is unavailable.
class VisitBillingPollService {
  VisitBillingPollService({
    required EmrService emr,
    required AuthSession auth,
    required PushNotificationService push,
  })  : _emr = emr,
        _auth = auth,
        _push = push;

  final EmrService _emr;
  final AuthSession _auth;
  final PushNotificationService _push;

  Timer? _timer;
  final Set<int> _knownVisitIds = {};

  void updateEnabled(bool enabled) {
    _timer?.cancel();
    _timer = null;
    final shouldRun = enabled &&
        _auth.isAuthenticated &&
        _auth.hasRole(AppRoles.cashier) &&
        AppConfig.isCashierPlatform;
    if (!shouldRun) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_poll());
    });
    unawaited(_poll());
  }

  Future<void> _poll() async {
    if (!_auth.isAuthenticated ||
        !_auth.hasRole(AppRoles.cashier) ||
        !AppConfig.isCashierPlatform) {
      return;
    }

    try {
      final result = await _emr.listVisitsPaginated(
        page: 1,
        perPage: 20,
        status: 'completed',
      );
      for (final visit in result.items) {
        if (_knownVisitIds.contains(visit.id)) continue;
        _knownVisitIds.add(visit.id);
        if (!_push.shouldNotifyForVisit(visit.id)) continue;
        await _push.showVisitReady(
          visitId: visit.id,
          title: 'Visit ready for billing',
          body: '${visit.pet?.name ?? 'Patient'} · ${visit.visitNumber}',
        );
        _push.markVisitSeen(visit.id);
      }
    } catch (e) {
      debugPrint('Visit billing poll failed: $e');
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
