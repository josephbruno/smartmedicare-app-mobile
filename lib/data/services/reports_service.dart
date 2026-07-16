import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/api_response.dart';
import '../models/report_data.dart';
import '../models/dashboard_data.dart';
import '../models/stock_transfer.dart';

class StockTransferReportSummary {
  StockTransferReportSummary({
    required this.total,
    required this.pending,
    required this.accepted,
    required this.rejected,
    required this.cancelled,
    required this.requestedQty,
    required this.acceptedQty,
  });

  final int total;
  final int pending;
  final int accepted;
  final int rejected;
  final int cancelled;
  final double requestedQty;
  final double acceptedQty;

  factory StockTransferReportSummary.fromJson(Map<String, dynamic> j) {
    return StockTransferReportSummary(
      total: intOrNull(j['total']) ?? 0,
      pending: intOrNull(j['pending']) ?? 0,
      accepted: intOrNull(j['accepted']) ?? 0,
      rejected: intOrNull(j['rejected']) ?? 0,
      cancelled: intOrNull(j['cancelled']) ?? 0,
      requestedQty: numOrNull(j['requested_qty']) ?? 0,
      acceptedQty: numOrNull(j['accepted_qty']) ?? 0,
    );
  }
}

class StockTransferReportResult {
  StockTransferReportResult({
    required this.items,
    required this.summary,
    this.meta,
  });

  final List<StockTransfer> items;
  final StockTransferReportSummary summary;
  final PaginationMeta? meta;
}

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

  /// Super Admin only — shop-wide stock transfer report.
  Future<StockTransferReportResult> stockTransfers({
    String? fromDate,
    String? toDate,
    String? status,
    int? fromBranchId,
    int? toBranchId,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final res = await _client.get(
        '/reports/stock-transfers',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (fromDate != null) 'from_date': fromDate,
          if (toDate != null) 'to_date': toDate,
          if (status != null && status.isNotEmpty) 'status': status,
          if (fromBranchId != null) 'from_branch_id': fromBranchId,
          if (toBranchId != null) 'to_branch_id': toBranchId,
        },
      );
      final map = responseAsMap(res);
      final ok = map['success'] as bool? ?? true;
      if (!ok) {
        throw Exception(map['message']?.toString() ?? 'Request failed');
      }
      return StockTransferReportResult(
        items: listFromData(map['data'], StockTransfer.fromJson),
        summary: StockTransferReportSummary.fromJson(
          Map<String, dynamic>.from(map['summary'] as Map? ?? const {}),
        ),
        meta: map['meta'] is Map
            ? PaginationMeta.fromJson(Map<String, dynamic>.from(map['meta'] as Map))
            : null,
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
