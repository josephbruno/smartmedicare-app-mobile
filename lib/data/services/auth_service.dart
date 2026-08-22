import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/user.dart';

class AuthService {
  AuthService(this._client);

  final ApiClient _client;

  Future<({User user, String token})> login(
    String login,
    String password,
  ) async {
    try {
      final res = await _client.post('/auth/login', data: {
        'login': login,
        'password': password,
      });
      return parseEnvelopeData(res, (data) {
        final m = mapOrNull(data)!;
        return (
          user: User.fromJson(Map<String, dynamic>.from(m['user'] as Map)),
          token: m['token']?.toString() ?? '',
        );
      });
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<({User user, String token})> register(
      Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/auth/register', data: body);
      return parseEnvelopeData(res, (data) {
        final m = mapOrNull(data)!;
        return (
          user: User.fromJson(Map<String, dynamic>.from(m['user'] as Map)),
          token: m['token']?.toString() ?? '',
        );
      });
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<User> me() async {
    try {
      final res = await _client.get('/auth/me');
      return parseEnvelopeData(
        res,
        (data) => User.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> logout() async {
    try {
      await _client.post('/auth/logout');
    } on DioException catch (_) {}
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _client.post('/auth/forgot-password', data: {'email': email});
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<User> switchBranch(int branchId) async {
    try {
      final res = await _client.post('/auth/switch-branch', data: {
        'branch_id': branchId,
      });
      return parseEnvelopeData(
        res,
        (data) => User.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<User> setPin(String pin) async {
    try {
      final res = await _client.post('/auth/set-pin', data: {'pin': pin});
      return parseEnvelopeData(
        res,
        (data) => User.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> verifyPin(String pin) async {
    try {
      await _client.post('/auth/unlock', data: {'code': pin});
    } on DioException catch (e) {
      // Older APIs only have /verify-pin; retry once if unlock is missing.
      if (e.response?.statusCode == 404) {
        try {
          await _client.post('/auth/verify-pin', data: {'code': pin});
          return;
        } on DioException catch (e2) {
          ApiClient.throwFromDio(e2);
        }
      }
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _client.post('/auth/change-password', data: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': newPassword,
      });
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<User> changePin({
    String? currentPin,
    required String newPin,
  }) async {
    try {
      final res = await _client.post('/auth/change-pin', data: {
        if (currentPin != null && currentPin.isNotEmpty)
          'current_pin': currentPin,
        'pin': newPin,
        'pin_confirmation': newPin,
      });
      return parseEnvelopeData(
        res,
        (data) => User.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
