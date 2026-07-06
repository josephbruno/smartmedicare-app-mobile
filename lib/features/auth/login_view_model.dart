import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/auth_session.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._auth);

  final AuthSession _auth;

  String email = '';
  String password = '';
  bool loading = false;
  String? error;

  Future<void> submit() async {
    error = null;
    loading = true;
    notifyListeners();
    try {
      await _auth.login(email.trim(), password);
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
