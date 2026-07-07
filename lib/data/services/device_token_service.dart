import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';

class DeviceTokenService {
  DeviceTokenService(this._client);

  final ApiClient _client;

  Future<void> register({
    required String fcmToken,
    required String platform,
    int? branchId,
    String? deviceName,
  }) async {
    try {
      await _client.post(
        '/device-tokens',
        data: {
          'fcm_token': fcmToken,
          'platform': platform,
          if (branchId != null) 'branch_id': branchId,
          if (deviceName != null) 'device_name': deviceName,
        },
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> unregister({required String fcmToken}) async {
    try {
      await _client.delete(
        '/device-tokens',
        data: {'fcm_token': fcmToken},
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
