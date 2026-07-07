import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/api_response.dart';
import '../models/purchase.dart';

class PurchaseService {
  PurchaseService(this._client);

  final ApiClient _client;

  Future<List<Purchase>> list({Map<String, dynamic>? query}) async {
    final result = await listPaginated(
      page: int.tryParse(query?['page']?.toString() ?? '') ?? 1,
      perPage: int.tryParse(query?['per_page']?.toString() ?? '') ?? 20,
    );
    return result.items;
  }

  Future<({List<Purchase> items, PaginationMeta? meta})> listPaginated({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final res = await _client.get('/purchases', queryParameters: {
        'page': page,
        'per_page': perPage,
      });
      return parseEnvelopeList(res, Purchase.fromJson);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Purchase> get(int id) async {
    try {
      final res = await _client.get('/purchases/$id');
      return parseEnvelopeData(
        res,
        (data) => Purchase.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Purchase> create(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/purchases', data: body);
      return parseEnvelopeData(
        res,
        (data) => Purchase.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}

class SupplierService {
  SupplierService(this._client);

  final ApiClient _client;

  Future<List<Supplier>> list({Map<String, dynamic>? query}) async {
    final result = await listPaginated(
      page: int.tryParse(query?['page']?.toString() ?? '') ?? 1,
      perPage: int.tryParse(query?['per_page']?.toString() ?? '') ?? 20,
    );
    return result.items;
  }

  Future<({List<Supplier> items, PaginationMeta? meta})> listPaginated({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final res = await _client.get('/suppliers', queryParameters: {
        'page': page,
        'per_page': perPage,
      });
      return parseEnvelopeList(res, Supplier.fromJson);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
