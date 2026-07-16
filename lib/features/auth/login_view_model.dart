import 'package:flutter/foundation.dart';

import '../../../core/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/session/auth_session.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._auth);

  final AuthSession _auth;

  String login = '';
  String password = '';
  bool loading = false;
  String? error;

  Future<void> submit() async {
    error = null;
    loading = true;
    notifyListeners();
    try {
      await _auth.login(login.trim(), password);
      if (_auth.hasRole(AppRoles.cashier) && !AppConfig.isCashierPlatform) {
        await _auth.logout();
        error =
            'Cashier accounts can only be used on the Windows or Linux desktop app.';
      }
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
