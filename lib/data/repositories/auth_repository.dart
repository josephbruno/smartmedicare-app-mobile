import '../models/user.dart';
import '../services/auth_service.dart';

class AuthRepository {
  AuthRepository(this._service);

  final AuthService _service;

  Future<({User user, String token})> login(String login, String password) =>
      _service.login(login, password);

  Future<({User user, String token})> register(Map<String, dynamic> body) =>
      _service.register(body);

  Future<User> me() => _service.me();

  Future<void> logout() => _service.logout();

  Future<void> forgotPassword(String email) =>
      _service.forgotPassword(email);

  Future<User> switchBranch(int branchId) => _service.switchBranch(branchId);

  Future<User> setPin(String pin) => _service.setPin(pin);

  Future<void> verifyPin(String pin) => _service.verifyPin(pin);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _service.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  Future<User> changePin({String? currentPin, required String newPin}) =>
      _service.changePin(currentPin: currentPin, newPin: newPin);
}
