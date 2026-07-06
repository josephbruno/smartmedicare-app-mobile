import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/purchase.dart';

class PurchaseService {
  PurchaseService(this._client);

  final ApiClient _client;

  Future<List<Purchase>> list({Map<String, dynamic>? query}) async {
    try {
      final res = await _client.get('/purchases', queryParameters: query);
      return parseEnvelopeData(res, (data) => listFromData(data, Purchase.fromJson));
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
    try {
      final res = await _client.get('/suppliers', queryParameters: query);
      return parseEnvelopeData(res, (data) => listFromData(data, Supplier.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
