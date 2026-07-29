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

  Future<Purchase> update(int id, Map<String, dynamic> body) async {
    try {
      final res = await _client.put('/purchases/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => Purchase.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Records a payment against a purchase.
  ///
  /// Prefers `POST /purchases/{id}/payment` (creates supplier payment + ledger).
  /// Falls back to `PUT /purchases/{id}` with cumulative [currentPaidAmount] + [amount]
  /// when that route is not yet available on the server (404).
  Future<Purchase> recordPayment(
    int id, {
    required double amount,
    required String paymentMode,
    required double currentPaidAmount,
    String? paymentDate,
    String? referenceNumber,
    String? notes,
  }) async {
    try {
      final res = await _client.post('/purchases/$id/payment', data: {
        'amount': amount,
        'payment_mode': paymentMode,
        if (paymentDate != null && paymentDate.isNotEmpty) 'payment_date': paymentDate,
        if (referenceNumber != null && referenceNumber.isNotEmpty)
          'reference_number': referenceNumber,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      return parseEnvelopeData(
        res,
        (data) => Purchase.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) {
        // Deployed API may not have POST /payment yet — update paid total via PUT.
        final newPaid = double.parse(
          (currentPaidAmount + amount).toStringAsFixed(2),
        );
        await update(id, {
          'paid_amount': newPaid,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        });
        return get(id);
      }
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

  Future<Supplier> create(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/suppliers', data: body);
      return parseEnvelopeData(
        res,
        (data) => Supplier.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Supplier> update(int id, Map<String, dynamic> body) async {
    try {
      final res = await _client.put('/suppliers/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => Supplier.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
