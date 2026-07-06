import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Online/offline indicator (similar to web `uiStore`).
class ConnectivityNotifier extends ChangeNotifier {
  ConnectivityNotifier() {
    _subscription = Connectivity().onConnectivityChanged.listen((r) {
      _online = _resultOnline(r);
      notifyListeners();
    });
    Connectivity().checkConnectivity().then((r) {
      _online = _resultOnline(r);
      notifyListeners();
    });
  }

  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _online = true;

  bool get isOnline => _online;

  static bool _resultOnline(List<ConnectivityResult> r) {
    return r.any((e) =>
        e == ConnectivityResult.wifi ||
        e == ConnectivityResult.ethernet ||
        e == ConnectivityResult.mobile);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
