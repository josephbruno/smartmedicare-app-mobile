import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/dashboard_data.dart';

class ReportsService {
  ReportsService(this._client);

  final ApiClient _client;

  Future<DashboardData> dashboard({int? branchId}) async {
    try {
      final res = await _client.get(
        '/reports/dashboard',
        queryParameters: branchId != null ? {'branch_id': branchId} : null,
      );
      return parseEnvelopeData(
        res,
        (data) => DashboardData.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
