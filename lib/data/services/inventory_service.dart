import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/inventory.dart';
import '../models/stock_transfer.dart';

class InventoryService {
  InventoryService(this._client);

  final ApiClient _client;

  Future<InventoryListResult> list({Map<String, dynamic>? query}) async {
    try {
      final res = await _client.get('/inventory', queryParameters: query);
      final parsed = parseEnvelopeList(res, InventoryItem.fromJson);
      InventoryListSummary? summary;
      final map = responseAsMap(res);
      if (map['meta'] is Map) {
        final meta = Map<String, dynamic>.from(map['meta'] as Map);
        if (meta['summary'] is Map) {
          summary = InventoryListSummary.fromJson(
            Map<String, dynamic>.from(meta['summary'] as Map),
          );
        }
      }
      return InventoryListResult(
        items: parsed.items,
        pagination: parsed.meta,
        summary: summary,
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<InventoryItem>> listSimple({Map<String, dynamic>? query}) async {
    final result = await list(query: query);
    return result.items;
  }

  Future<List<StockMovement>> movements({Map<String, dynamic>? query}) async {
    try {
      final res =
          await _client.get('/inventory/movements', queryParameters: query);
      return parseEnvelopeData(
        res,
        (data) => listFromData(data, StockMovement.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<StockAgeingItem>> ageing({Map<String, dynamic>? query}) async {
    try {
      final res = await _client.get('/inventory/ageing', queryParameters: query);
      return parseEnvelopeData(
        res,
        (data) => listFromData(data, StockAgeingItem.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> adjust(Map<String, dynamic> body) async {
    try {
      await _client.post('/inventory/adjust', data: body);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<StockTransfer>> listTransfers({Map<String, dynamic>? query}) async {
    try {
      final res =
          await _client.get('/inventory/transfers', queryParameters: query);
      return parseEnvelopeData(
        res,
        (data) => listFromData(data, StockTransfer.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<StockTransfer> getTransfer(int id) async {
    try {
      final res = await _client.get('/inventory/transfers/$id');
      return parseEnvelopeData(
        res,
        (data) => StockTransfer.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<StockTransfer> createTransfer(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/inventory/transfers', data: body);
      return parseEnvelopeData(
        res,
        (data) => StockTransfer.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> acceptTransfer(int id, Map<String, dynamic> body) async {
    try {
      await _client.post('/inventory/transfers/$id/accept', data: body);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> rejectTransfer(int id, Map<String, dynamic> body) async {
    try {
      await _client.post('/inventory/transfers/$id/reject', data: body);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> cancelTransfer(int id) async {
    try {
      await _client.post('/inventory/transfers/$id/cancel');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
