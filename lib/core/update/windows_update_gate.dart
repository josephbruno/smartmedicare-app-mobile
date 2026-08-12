import 'dart:async';

import 'package:flutter/foundation.dart';

/// Blocks splash → login/dashboard navigation while a Windows update
/// check, prompt, or download is in progress.
class WindowsUpdateGate extends ChangeNotifier {
  WindowsUpdateGate._();
  static final WindowsUpdateGate instance = WindowsUpdateGate._();

  bool _holdsSplash = false;
  final List<Completer<void>> _waiters = [];

  /// True while startup should stay on `/splash` (or return to it).
  bool get holdsSplash => _holdsSplash;

  void acquire() {
    if (_holdsSplash) return;
    _holdsSplash = true;
    notifyListeners();
  }

  void release() {
    if (!_holdsSplash) return;
    _holdsSplash = false;
    notifyListeners();
    final pending = List<Completer<void>>.from(_waiters);
    _waiters.clear();
    for (final c in pending) {
      if (!c.isCompleted) c.complete();
    }
  }

  /// Resolves immediately when not holding; otherwise when [release] runs.
  Future<void> waitIfHeld() async {
    if (!_holdsSplash) return;
    final c = Completer<void>();
    _waiters.add(c);
    // release() may have run between the check and registering the waiter.
    if (!_holdsSplash) {
      _waiters.remove(c);
      if (!c.isCompleted) c.complete();
    }
    return c.future;
  }
}
