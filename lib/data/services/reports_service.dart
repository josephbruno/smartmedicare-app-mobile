import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/report_data.dart';
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

  Future<SalesTrendData> salesTrend({int days = 30, int? branchId}) async {
    try {
      final res = await _client.get(
        '/reports/sales-trend',
        queryParameters: {
          'days': days,
          if (branchId != null) 'branch_id': branchId,
        },
      );
      return parseEnvelopeData(
        res,
        (data) => SalesTrendData.fromJson(data),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
