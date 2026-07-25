import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/cashier_cash_session.dart';

class CashierCashSessionService {
  CashierCashSessionService(this._client);

  final ApiClient _client;

  Future<CashierCurrentSessionResult> current() async {
    try {
      final res = await _client.get('/cashier/cash-session/current');
      return parseEnvelopeData(
        res,
        (data) => CashierCurrentSessionResult.fromJson(
          Map<String, dynamic>.from(data as Map),
        ),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<CashierCashSession> start({
    required double openingAmount,
    String? notes,
  }) async {
    try {
      final res = await _client.post('/cashier/cash-session/start', data: {
        'opening_amount': openingAmount,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      return parseEnvelopeData(
        res,
        (data) => CashierCashSession.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<CashierCashSession> end({
    required int sessionId,
    required double countedAmount,
    String? notes,
  }) async {
    try {
      final res = await _client.post('/cashier/cash-session/$sessionId/end', data: {
        'counted_amount': countedAmount,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      return parseEnvelopeData(
        res,
        (data) => CashierCashSession.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<CashierDayStatus> dayStatus({String? date}) async {
    try {
      final res = await _client.get('/cashier/day-close/status', queryParameters: {
        if (date != null && date.isNotEmpty) 'date': date,
      });
      return parseEnvelopeData(
        res,
        (data) => CashierDayStatus.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<CashierDayStatus> dayClose({String? businessDate, String? notes}) async {
    try {
      final res = await _client.post('/cashier/day-close', data: {
        if (businessDate != null && businessDate.isNotEmpty) 'business_date': businessDate,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      return parseEnvelopeData(
        res,
        (data) => CashierDayStatus.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
