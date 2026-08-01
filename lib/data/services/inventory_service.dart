import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../json_helpers.dart';
import '../models/inventory.dart';
import '../models/api_response.dart';
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
    final result = await movementsPaginated(
      page: int.tryParse(query?['page']?.toString() ?? '') ?? 1,
      perPage: int.tryParse(query?['per_page']?.toString() ?? '') ?? 20,
      productId: int.tryParse(query?['product_id']?.toString() ?? ''),
      type: query?['type']?.toString(),
      manualOnly: query?['manual_only'] == true || query?['manual_only'] == 'true' || query?['manual_only'] == 1,
      dateFrom: query?['date_from']?.toString(),
      dateTo: query?['date_to']?.toString(),
    );
    return result.items;
  }

  Future<({List<StockMovement> items, PaginationMeta? meta})> movementsPaginated({
    int page = 1,
    int perPage = 20,
    int? productId,
    String? search,
    String? type,
    bool manualOnly = false,
    String? dateFrom,
    String? dateTo,
    int? userId,
  }) async {
    try {
      final res = await _client.get('/inventory/movements', queryParameters: {
        'page': page,
        'per_page': perPage,
        if (productId != null) 'product_id': productId,
        if (search != null && search.isNotEmpty) 'search': search,
        if (type != null && type.isNotEmpty) 'type': type,
        if (manualOnly) 'manual_only': true,
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
        if (userId != null) 'user_id': userId,
      });
      return parseEnvelopeList(res, StockMovement.fromJson);
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

  Future<MonthlySnapshotResult> monthlySnapshot({
    required String month,
    int page = 1,
    int perPage = 100,
  }) async {
    try {
      final res = await _client.get(
        '/inventory/monthly-snapshot',
        queryParameters: {
          'month': month,
          'page': page,
          'per_page': perPage.clamp(1, 100),
        },
      );
      final map = responseAsMap(res);
      final ok = map['success'] as bool? ?? true;
      if (!ok) {
        throw ApiException(map['message']?.toString() ?? 'Request failed');
      }
      final dateRange = (map['date_range'] is List)
          ? (map['date_range'] as List).map((e) => e.toString()).toList()
          : <String>[];
      return MonthlySnapshotResult(
        rows: listFromData(map['data'], MonthlyAgeingRow.fromJson),
        dateRange: dateRange,
        month: map['month']?.toString() ?? month,
        monthLabel: map['month_label']?.toString() ?? month,
        meta: map['meta'] is Map
            ? PaginationMeta.fromJson(
                Map<String, dynamic>.from(map['meta'] as Map),
              )
            : null,
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<({List<InventoryItem> items, PaginationMeta? meta})> listPaginated({
    int page = 1,
    int perPage = 20,
    bool includeSummary = true,
    String? search,
    int? categoryId,
    bool? lowStock,
  }) async {
    final result = await list(query: {
      'page': page,
      'per_page': perPage,
      if (includeSummary) 'include_summary': true,
      if (search != null && search.isNotEmpty) 'search': search,
      if (categoryId != null) 'category_id': categoryId,
      if (lowStock == true) 'low_stock': 'true',
    });
    return (items: result.items, meta: result.pagination);
  }

  Future<void> adjust(Map<String, dynamic> body) async {
    try {
      await _client.post('/inventory/adjust', data: body);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<StockTransfer>> listTransfers({Map<String, dynamic>? query}) async {
    final result = await listTransfersPaginated(
      page: int.tryParse(query?['page']?.toString() ?? '') ?? 1,
      perPage: int.tryParse(query?['per_page']?.toString() ?? '') ?? 20,
      direction: query?['direction']?.toString(),
    );
    return result.items;
  }

  Future<({List<StockTransfer> items, PaginationMeta? meta})> listTransfersPaginated({
    int page = 1,
    int perPage = 20,
    String? direction,
  }) async {
    try {
      final res = await _client.get('/inventory/transfers', queryParameters: {
        'page': page,
        'per_page': perPage,
        if (direction != null && direction.isNotEmpty) 'direction': direction,
      });
      return parseEnvelopeList(res, StockTransfer.fromJson);
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
