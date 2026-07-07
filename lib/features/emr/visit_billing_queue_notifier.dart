import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/emr.dart';
import '../../data/services/emr_service.dart';

/// Keeps visit lists fresh for cashier billing queue and doctor handoff views.
class VisitBillingQueueNotifier extends ChangeNotifier {
  List<PetVisit> readyForBilling = [];
  List<PetVisit> onHold = [];
  bool loading = false;
  String? error;

  Timer? _timer;
  EmrService? _emr;

  void startPolling(EmrService emr, {Duration interval = const Duration(seconds: 30)}) {
    _emr = emr;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(refresh()));
    unawaited(refresh());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() async {
    final emr = _emr;
    if (emr == null) return;

    loading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        emr.listVisitsPaginated(status: 'completed', perPage: 40),
        emr.listVisitsPaginated(status: 'bill_on_hold', perPage: 20),
      ]);
      readyForBilling = results[0].items;
      onHold = results[1].items;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
