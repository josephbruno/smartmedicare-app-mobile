import 'package:flutter/foundation.dart';

import '../../app_services.dart';
import '../../data/models/dashboard_data.dart';

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel(this._services);

  final AppServices _services;

  DashboardData? data;
  String? error;
  bool loading = true;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    loading = true;
    error = null;
    _notify();
    try {
      data = await _services.reports.dashboard();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
